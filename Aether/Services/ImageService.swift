import Nuke

enum ImageService {
    static func configure() {
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache(
            name: "me.athion.luma.images",
            sizeLimit: 500 * 1024 * 1024  // 500 MB
        ))
    }
}
