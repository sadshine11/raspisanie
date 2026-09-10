import SwiftUI
import UIKit

/// Оформление системных панелей — их SwiftUI-модификаторами не достать.
///
/// Без этого панель вкладок и заголовок берут системный тёмно-серый фон,
/// который на фоне `Theme.background` выглядит светлой полосой сверху и снизу.
enum Appearance {

    static func apply() {
        applyTabBar()
        applyNavigationBar()
    }

    private static func applyTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.72)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(Theme.textSecondary)
            item.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Theme.textSecondary),
                .font: barFont(size: 10, weight: .medium),
            ]
            item.selected.iconColor = UIColor(Theme.accent)
            item.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Theme.accent),
                .font: barFont(size: 10, weight: .semibold),
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func applyNavigationBar() {
        let title: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: barFont(size: 17, weight: .semibold),
        ]
        let largeTitle: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: barFont(size: 32, weight: .bold),
        ]

        // Пока экран не прокручен, панель прозрачная и заголовок лежит прямо
        // на градиенте фона; при прокрутке под него подставляется размытие.
        let atTop = UINavigationBarAppearance()
        atTop.configureWithTransparentBackground()
        atTop.titleTextAttributes = title
        atTop.largeTitleTextAttributes = largeTitle

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.6)
        scrolled.shadowColor = UIColor.white.withAlphaComponent(0.08)
        scrolled.titleTextAttributes = title
        scrolled.largeTitleTextAttributes = largeTitle

        UINavigationBar.appearance().scrollEdgeAppearance = atTop
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
    }

    /// Тот же шрифт, что и в содержимом.
    private static func barFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
}
