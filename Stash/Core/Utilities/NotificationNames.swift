import Foundation

extension Notification.Name {
    /// Posted when a scene is successfully added to Whisparr
    static let whisparrSceneAdded = Notification.Name("whisparrSceneAdded")
    
    /// Posted when a file is deleted from Whisparr
    static let whisparrFileDeleted = Notification.Name("whisparrFileDeleted")
    
    /// Posted when any change occurs in Whisparr that requires a library refresh
    static let whisparrLibraryChanged = Notification.Name("whisparrLibraryChanged")
    
    /// Posted when the Stash database has changed (scene deleted, etc.)
    static let stashDatabaseChanged = Notification.Name("stashDatabaseChanged")
    
    /// Posted when the Whisparr search sheet should be dismissed
    static let dismissWhisparrSearch = Notification.Name("dismissWhisparrSearch")
    
    /// Posted when a specific Whisparr movie is updated (download completed, etc.)
    /// userInfo contains: "movieId" (Int), "movie" (WhisparrMovie)
    static let whisparrMovieUpdated = Notification.Name("whisparrMovieUpdated")
    
    /// Posted when a Whisparr movie is deleted
    /// userInfo contains: "movieId" (Int)
    static let whisparrMovieDeleted = Notification.Name("whisparrMovieDeleted")
    
    /// Posted when a scene's details are updated in the local database
    /// userInfo contains: "id" (String)
    static let sceneUpdated = Notification.Name("sceneUpdated")
    
    /// Posted when a Stash job (background task) is completed
    /// userInfo contains: "job" (Job)
    static let stashJobCompleted = Notification.Name("stashJobCompleted")
    
    /// Posted when all active jobs in the Stash queue have finished
    /// userInfo contains: "hasIdentify" (Bool)
    static let stashAllJobsCompleted = Notification.Name("stashAllJobsCompleted")
    
    /// Posted when the user adds or removes a followed tag
    static let followedTagsChanged = Notification.Name("followedTagsChanged")
    
    /// Posted when the user changes the category row order
    static let categoryOrderChanged = Notification.Name("categoryOrderChanged")
}
