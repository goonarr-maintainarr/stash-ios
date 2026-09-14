import Foundation

struct TagResultDTO: Decodable {
    struct FindTags: Decodable {
        let count: Int
        let tags: [Tag]
    }
    let findTags: FindTags
}

struct TagCreateResultDTO: Decodable {
    struct TagCreate: Decodable {
        let id: String
    }
    let tagCreate: TagCreate
}
