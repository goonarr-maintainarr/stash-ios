import SwiftUI
import NukeUI

struct HeroBackgroundModifier: ViewModifier {
    let imageUrl: URL?
    let heroColor: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if let url = imageUrl {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .blur(radius: 20)
                                    .overlay(Color.black.opacity(0.7))
                            } else {
                                Color.stashBackground
                            }
                        }
                    } else {
                        Color.stashBackground
                    }
                }
                .ignoresSafeArea()
            )
            .withHeroAccentColor(heroColor)
    }
}

extension View {
    func heroBackground(imageUrl: URL?, heroColor: Color? = nil) -> some View {
        self.modifier(HeroBackgroundModifier(imageUrl: imageUrl, heroColor: heroColor))
    }
}
