// System-wide hotkey registration via Carbon's RegisterEventHotKey.
//
// Why Carbon and not NSEvent.addGlobalMonitorForEvents:
//   - No Accessibility permission required (survives rebuilds during dev)
//   - Consumes the keystroke (does not leak to the focused app)
// This is the same mechanism used by KeyboardShortcuts/MASShortcut/HotKey.
//
// Each registered hotkey gets a unique integer id. A single Carbon event
// handler dispatches by id to the stored Swift closure. The string->keycode
// and modifier parsing live here too so the rest of the app stays Cocoa-only.

import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    // Maps our hotkey id -> action closure to run when it fires.
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    // Register a hotkey. Returns true on success.
    @discardableResult
    func register(key: String, modifiers: [String], handler: @escaping () -> Void) -> Bool {
        guard let keyCode = HotkeyManager.keyCode(for: key) else {
            Log.write("HotkeyManager: unknown key '\(key)'")
            return false
        }
        let carbonMods = HotkeyManager.carbonModifiers(modifiers)
        let id = nextID
        nextID += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)

        let status = RegisterEventHotKey(
            keyCode,
            carbonMods,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            Log.write("HotkeyManager: RegisterEventHotKey failed for \(key)+\(modifiers), status=\(status)")
            return false
        }

        handlers[id] = handler
        hotKeyRefs[id] = ref
        Log.write("HotkeyManager: registered id=\(id) key=\(key) code=\(keyCode) mods=\(modifiers) carbonMods=\(carbonMods)")
        return true
    }

    // Install one Carbon handler for all hotkey-pressed events.
    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass `self` through the userData pointer so the C callback can call back in.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event = event, let userData = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    manager.fire(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func fire(id: UInt32) {
        handlers[id]?()
    }

    // MARK: - Key / modifier mapping

    // 4-char signature identifying our hotkeys ("VPND").
    private static let signature: OSType = {
        let chars = Array("VPND".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    private static func carbonModifiers(_ modifiers: [String]) -> UInt32 {
        var flags: UInt32 = 0
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command": flags |= UInt32(cmdKey)
            case "opt", "option", "alt": flags |= UInt32(optionKey)
            case "shift": flags |= UInt32(shiftKey)
            case "ctrl", "control": flags |= UInt32(controlKey)
            default: break
            }
        }
        return flags
    }

    private static func keyCode(for key: String) -> UInt32? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab, "escape": kVK_Escape,
        ]
        guard let code = map[key.lowercased()] else { return nil }
        return UInt32(code)
    }
}
