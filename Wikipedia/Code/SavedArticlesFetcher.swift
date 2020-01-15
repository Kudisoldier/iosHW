
import Foundation

@objc(WMFSavedArticlesFetcher)
final class SavedArticlesFetcher: NSObject {
    
    @objc var progress: Progress?
    var fetchesInProcessCount: NSNumber = 0
    
    private let dataStore: MWKDataStore
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private let articleCacheController: ArticleCacheController
    private let spotlightManager: WMFSavedPageSpotlightManager
    
    private var isRunning = false
    private var isUpdating = false
    
    private var currentlyFetchingArticleKeys: [String] = []
    
    @objc init?(dataStore: MWKDataStore) {
        self.dataStore = dataStore
        
        if let articleCacheController = dataStore.articleCacheControllerWrapper.cacheController as? ArticleCacheController {
            self.articleCacheController = articleCacheController
        } else {
            return nil
        }
        
        spotlightManager = WMFSavedPageSpotlightManager(dataStore: dataStore)
        
        super.init()
        updateFetchesInProcessCount()
    }
    
    @objc func start() {
        self.isRunning = true
        observeSavedPages()
    }
    
    @objc func stop() {
        self.isRunning = false
        unobserveSavedPages()
    }
}

private extension SavedArticlesFetcher {
    func updateFetchesInProcessCount() {
        if let count = calculateTotalArticlesToFetchCount() {
            fetchesInProcessCount = NSNumber(value: count)
        }
        
    }
    
    func calculateTotalArticlesToFetchCount() -> UInt? {
        assert(Thread.isMainThread)
        
        let moc = dataStore.viewContext
        let request = WMFArticle.fetchRequest()
        request.includesSubentities = false
        request.predicate = NSPredicate(format: "savedDate != NULL && isDownloaded != YES")
        
        do {
            let count = try moc.count(for: request)
            return (count >= 0) ? UInt(count) : nil
        } catch(let error) {
            DDLogError("Error counting number of article to be downloaded: \(error)")
            return nil
        }
    }
    
    func observeSavedPages() {
        NotificationCenter.default.addObserver(self, selector: #selector(articleWasUpdated(_:)), name: NSNotification.Name.WMFArticleUpdated, object: nil)
        // WMFArticleUpdatedNotification aren't coming through when the articles are created from a background sync, so observe syncDidFinish as well to download articles synced down from the server
        NotificationCenter.default.addObserver(self, selector: #selector(syncDidFinish), name: ReadingListsController.syncDidFinishNotification, object: nil)
    }
    
    @objc func articleWasUpdated(_ note: Notification) {
        update()
    }
    
    @objc func syncDidFinish(_ note: Notification) {
        
    }
    
    func unobserveSavedPages() {
        NotificationCenter.default.removeObserver(self)
    }
    
    func cancelAllRequests() {
        for articleKey in currentlyFetchingArticleKeys {
            articleCacheController.cancelTasks(groupKey: articleKey)
        }
    }
    
    func update() {
        assert(Thread.isMainThread)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_update), object: nil)
        perform(#selector(_update), with: nil, afterDelay: 0.5)
    }
    
    @objc func _update() {
        if isUpdating || !isRunning {
            updateFetchesInProcessCount()
            return
        }
        
        isUpdating = true
        
        let endBackgroundTask = {
            if let backgroundTaskIdentifier = self.backgroundTaskIdentifier {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                self.backgroundTaskIdentifier = nil
            }
        }
        
        if backgroundTaskIdentifier == nil {
            self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "SavedArticlesFetch", expirationHandler: {
                self.cancelAllRequests()
                self.stop()
                endBackgroundTask()
            })
        }
        
        assert(Thread.isMainThread)
        
        let moc = dataStore.viewContext
        let request = WMFArticle.fetchRequest()
        request.predicate = NSPredicate(format: "savedDate != NULL && isDownloaded != YES")
        request.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: true)]
        request.fetchLimit = 1
        
        var article: WMFArticle?
        do {
            article = try moc.fetch(request).first
        } catch (let error) {
            DDLogError("Error fetching next article to download: \(error)");
        }
        
        let updateAgain = {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.isUpdating = false
                self.update()
            }
        }
        
        if let articleURL = article?.url,
            let articleKey = articleURL.wmf_databaseKey {
            
            articleCacheController.add(url: articleURL, groupKey: articleKey, itemCompletion: { (itemResult) in
                switch itemResult {
                case .success(let itemKey):
                    print("🥶successfully added \(itemKey)")
                case .failure(let error):
                    print("🥶failure in itemCompletion of \(articleKey): \(error)")
                }
            }) { (groupResult) in
                DispatchQueue.main.async {
                    switch groupResult {
                    case .success(let itemKeys):
                        print("🥶group completion: \(articleKey), itemKeyCount: \(itemKeys.count)")
                        self.didFetchArticle(with: articleKey)
                        self.spotlightManager.addToIndex(url: articleURL as NSURL)
                        self.updateFetchesInProcessCount()
                    case .failure(let error):
                        print("🥶failure in groupCompletion of \(articleKey): \(error)")
                        self.updateFetchesInProcessCount()
                        self.didFailToFetchArticle(with: articleKey, error: error)
                    }
                    updateAgain()
                }
            }
        } else {
            let downloadedRequest = WMFArticle.fetchRequest()
            downloadedRequest.predicate = NSPredicate(format: "savedDate == NULL && isDownloaded == YES")
            downloadedRequest.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: true)]
            downloadedRequest.fetchLimit = 1
            
            var articleToDelete: WMFArticle?
            do {
                articleToDelete = try moc.fetch(downloadedRequest).first
            } catch (let error) {
                DDLogError("Error fetching downloaded unsaved articles: \(error)");
            }
            
            let noArticleToDeleteCompletion = {
                self.isUpdating = false
                self.updateFetchesInProcessCount()
                endBackgroundTask()
            }
            
            if let articleToDelete = articleToDelete {
                
                guard let articleKey = articleToDelete.url?.wmf_databaseKey else {
                    noArticleToDeleteCompletion()
                    return
                }
                
                articleCacheController.remove(groupKey: articleKey, itemCompletion: { (itemResult) in
                    switch itemResult {
                    case .success(let itemKey):
                        print("🙈successfully removed \(itemKey)")
                    case .failure(let error):
                        print("🙈failure in itemCompletion of \(articleKey): \(error)")
                    }
                }) { (groupResult) in
                    DispatchQueue.main.async {
                        switch groupResult {
                        case .success:
                            print("🙈success in groupCompletion of \(articleKey)")
                            self.didRemoveArticle(with: articleKey)
                            self.updateFetchesInProcessCount()
                        case .failure:
                            print("🙈failure in groupCompletion of \(articleKey)")
                            break
                        }
                        updateAgain()
                    }
                }
            } else {
                noArticleToDeleteCompletion()
            }
        }
    }
    
    func didFetchArticle(with key: String) {
        operateOnArticles(with: key) { (article) in
            article.isDownloaded = true
        }
    }
    
    func didFailToFetchArticle(with key: String, error: Error) {
        operateOnArticles(with: key) { (article) in
            article.updatePropertiesForError(error as NSError)
            article.isDownloaded = false
        }
    }

    func didRemoveArticle(with key: String) {
        operateOnArticles(with: key) { (article) in
            article.isDownloaded = false
        }
    }
    
    func operateOnArticles(with key: String, articleBlock: (WMFArticle) -> Void) {
        do {
            let articles = try dataStore.viewContext.fetchArticles(withKey: key)
            for article in articles {
                articleBlock(article)
            }
        } catch (let error) {
            DDLogError("Error fetching WMFArticles after caching: \(error)");
        }
        
        do {
            try dataStore.save()
        } catch (let error) {
            DDLogError("Error saving after saved articles fetch: \(error)");
        }
    }
}
