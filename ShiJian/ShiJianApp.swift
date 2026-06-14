import SwiftUI

@main
struct ShiJianApp: App {
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 1100, minHeight: 680)
                .preferredColorScheme(vm.isDarkMode ? .dark : .light)
                .accentColor(Color(hex: "#d4a64a"))
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { vm.undo() }.keyboardShortcut("z", modifiers: .command)
                Button("重做") { vm.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Button("导出图片…") { vm.exportToFile() }.keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
