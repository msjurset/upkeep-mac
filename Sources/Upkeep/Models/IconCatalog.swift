import AppKit
import Foundation

/// A curated SF Symbol entry with keyword aliases for fuzzy-search.
struct CatalogIcon: Identifiable, Hashable, Sendable {
    let name: String
    let aliases: [String]
    let group: IconGroup
    var id: String { name }
}

enum IconGroup: String, CaseIterable, Sendable {
    case home = "Home"
    case rooms = "Rooms & Furniture"
    case tools = "Tools"
    case cleaning = "Cleaning"
    case appliances = "Appliances"
    case outdoor = "Outdoor & Garden"
    case utilities = "Utilities"
    case lifestyle = "Lifestyle"
    case misc = "Misc"
}

/// Curated catalog of SF Symbols relevant to home maintenance, with keyword aliases.
/// Search matches against the name OR any alias (substring, case-insensitive).
/// Users can also type any SF Symbol name directly in the picker — the literal name
/// is previewed live even if it's not in this catalog.
///
/// **Runtime availability filtering:** SF Symbols ships with each macOS release and
/// evolves over time. A symbol added in SF Symbols 7 (macOS 26) won't render on a
/// machine running macOS 15 with SF Symbols 6. To keep the icon picker consistent for
/// every user regardless of macOS version, the public `icons` array is filtered at
/// launch to only symbols that resolve on the *current* system — broken cells never
/// appear.
enum IconCatalog {
    /// Public, filtered icon list — only contains symbols available on this macOS.
    static let icons: [CatalogIcon] = allIcons.filter(isAvailable)

    /// Checks whether an SF Symbol renders on the current system.
    static func isAvailable(_ icon: CatalogIcon) -> Bool {
        NSImage(systemSymbolName: icon.name, accessibilityDescription: nil) != nil
    }

    static func isAvailable(symbolName: String) -> Bool {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
    }

    /// Returns `name` if it resolves on the current system, otherwise `fallback`.
    /// Used so items saved with a custom icon that was valid on one Mac still render
    /// as the category default (or a universal last-resort symbol) on another Mac
    /// whose SF Symbols library is older or different.
    static func resolvedSymbolName(_ name: String, fallback: String) -> String {
        if isAvailable(symbolName: name) { return name }
        if isAvailable(symbolName: fallback) { return fallback }
        return "square"
    }

    /// The full curated catalog before availability filtering. Kept private so callers
    /// always go through the filtered `icons` property.
    private static let allIcons: [CatalogIcon] = [
        // MARK: Home
        .init(name: "house", aliases: ["home", "building"], group: .home),
        .init(name: "house.fill", aliases: ["home", "building"], group: .home),
        .init(name: "house.lodge", aliases: ["cabin", "chalet"], group: .home),
        .init(name: "building.2", aliases: ["condo", "apartment"], group: .home),
        .init(name: "door.left.hand.open", aliases: ["entry", "entrance", "doorway"], group: .home),
        .init(name: "door.french.closed", aliases: ["french doors", "patio"], group: .home),
        .init(name: "door.garage.closed", aliases: ["garage"], group: .home),
        .init(name: "door.sliding.left.hand.closed", aliases: ["sliding door", "patio"], group: .home),
        .init(name: "window.awning", aliases: ["window"], group: .home),
        .init(name: "window.vertical.closed", aliases: ["window"], group: .home),
        .init(name: "stairs", aliases: ["steps", "staircase", "stairway"], group: .home),
        .init(name: "house.lodge.fill", aliases: ["cabin", "chalet"], group: .home),
        .init(name: "house.and.flag", aliases: ["property", "address"], group: .home),
        .init(name: "fireplace", aliases: ["chimney", "hearth", "fire"], group: .home),
        .init(name: "chair.lounge.fill", aliases: ["patio", "deck"], group: .home),

        // MARK: Rooms & Furniture
        .init(name: "bed.double", aliases: ["bedroom", "mattress", "sleep"], group: .rooms),
        .init(name: "bed.double.fill", aliases: ["bedroom", "mattress", "sleep"], group: .rooms),
        .init(name: "sofa", aliases: ["couch", "living room"], group: .rooms),
        .init(name: "sofa.fill", aliases: ["couch", "living room"], group: .rooms),
        .init(name: "chair", aliases: ["seat", "dining"], group: .rooms),
        .init(name: "chair.fill", aliases: ["seat", "dining"], group: .rooms),
        .init(name: "table.furniture", aliases: ["table", "desk", "dining"], group: .rooms),
        .init(name: "lamp.desk", aliases: ["light", "desk lamp"], group: .rooms),
        .init(name: "lamp.desk.fill", aliases: ["light", "desk lamp"], group: .rooms),
        .init(name: "lamp.floor", aliases: ["light", "floor lamp"], group: .rooms),
        .init(name: "lamp.floor.fill", aliases: ["light", "floor lamp"], group: .rooms),
        .init(name: "lamp.ceiling", aliases: ["light", "ceiling light"], group: .rooms),
        .init(name: "lamp.ceiling.fill", aliases: ["light", "ceiling light"], group: .rooms),
        .init(name: "lamp.table", aliases: ["light", "table lamp"], group: .rooms),
        .init(name: "lamp.table.fill", aliases: ["light", "table lamp"], group: .rooms),
        .init(name: "lightbulb", aliases: ["light", "bulb", "idea"], group: .rooms),
        .init(name: "lightbulb.fill", aliases: ["light", "bulb"], group: .rooms),
        .init(name: "lightbulb.2", aliases: ["lights", "bulbs"], group: .rooms),
        .init(name: "lightbulb.2.fill", aliases: ["lights", "bulbs"], group: .rooms),
        .init(name: "lightbulb.led", aliases: ["led", "light", "bulb"], group: .rooms),
        .init(name: "bathtub", aliases: ["bath", "bathroom", "tub"], group: .rooms),
        .init(name: "bathtub.fill", aliases: ["bath", "bathroom", "tub"], group: .rooms),
        .init(name: "shower", aliases: ["bathroom"], group: .rooms),
        .init(name: "shower.fill", aliases: ["bathroom"], group: .rooms),
        .init(name: "toilet", aliases: ["bathroom", "plumbing"], group: .rooms),
        .init(name: "toilet.fill", aliases: ["bathroom", "plumbing"], group: .rooms),
        .init(name: "sink", aliases: ["kitchen", "bathroom", "plumbing"], group: .rooms),
        .init(name: "sink.fill", aliases: ["kitchen", "bathroom", "plumbing"], group: .rooms),
        .init(name: "fork.knife", aliases: ["dining", "kitchen", "dining room"], group: .rooms),
        .init(name: "books.vertical", aliases: ["shelf", "bookshelf", "library", "reading"], group: .rooms),
        .init(name: "books.vertical.fill", aliases: ["shelf", "bookshelf", "library", "reading"], group: .rooms),
        .init(name: "cabinet", aliases: ["storage", "cupboard", "closet"], group: .rooms),
        .init(name: "cabinet.fill", aliases: ["storage", "cupboard", "closet"], group: .rooms),
        .init(name: "rectangle.stack", aliases: ["carpet", "rug", "floor", "tile", "layers", "stack"], group: .rooms),
        .init(name: "square.grid.3x3", aliases: ["tile", "grid", "floor"], group: .rooms),
        .init(name: "square.grid.4x3.fill", aliases: ["tile", "grid", "floor"], group: .rooms),

        // MARK: Tools
        .init(name: "wrench.adjustable", aliases: ["tool", "plumbing", "fix"], group: .tools),
        .init(name: "wrench.and.screwdriver", aliases: ["tools", "handyman", "repair"], group: .tools),
        .init(name: "screwdriver", aliases: ["tool", "fix"], group: .tools),
        .init(name: "hammer", aliases: ["tool", "build", "nail"], group: .tools),
        .init(name: "hammer.fill", aliases: ["tool", "build", "nail"], group: .tools),
        .init(name: "paintbrush", aliases: ["paint", "brush", "art"], group: .tools),
        .init(name: "paintbrush.fill", aliases: ["paint", "brush"], group: .tools),
        .init(name: "paintbrush.pointed", aliases: ["paint", "detail"], group: .tools),
        .init(name: "paintbrush.pointed.fill", aliases: ["paint", "detail"], group: .tools),
        .init(name: "paintpalette", aliases: ["paint", "color"], group: .tools),
        .init(name: "scissors", aliases: ["cut", "trim"], group: .tools),
        .init(name: "ruler", aliases: ["measure", "length"], group: .tools),
        .init(name: "ruler.fill", aliases: ["measure", "length"], group: .tools),
        .init(name: "level", aliases: ["measure", "flat", "horizontal"], group: .tools),
        .init(name: "pencil.tip", aliases: ["write", "mark"], group: .tools),
        .init(name: "wrench.adjustable.fill", aliases: ["tool", "plumbing", "fix"], group: .tools),
        .init(name: "screwdriver.fill", aliases: ["tool", "fix"], group: .tools),
        .init(name: "hammer.circle", aliases: ["tool", "build"], group: .tools),
        .init(name: "hammer.circle.fill", aliases: ["tool", "build"], group: .tools),
        .init(name: "powerplug", aliases: ["plug", "electrical", "outlet"], group: .tools),
        .init(name: "powerplug.fill", aliases: ["plug", "electrical", "outlet"], group: .tools),

        // MARK: Cleaning
        .init(name: "sparkles", aliases: ["clean", "shine", "new"], group: .cleaning),
        .init(name: "sparkle", aliases: ["clean", "shine"], group: .cleaning),
        .init(name: "bubbles.and.sparkles", aliases: ["wash", "clean", "laundry", "soap"], group: .cleaning),
        .init(name: "hands.sparkles", aliases: ["wash hands", "clean", "sanitize"], group: .cleaning),
        .init(name: "hands.and.sparkles", aliases: ["wash hands", "clean"], group: .cleaning),
        .init(name: "hands.and.sparkles.fill", aliases: ["wash hands", "clean"], group: .cleaning),
        .init(name: "trash", aliases: ["delete", "garbage", "waste"], group: .cleaning),
        .init(name: "trash.fill", aliases: ["delete", "garbage", "waste"], group: .cleaning),
        .init(name: "basket", aliases: ["laundry", "pail", "clean"], group: .cleaning),
        .init(name: "basket.fill", aliases: ["laundry", "pail", "clean"], group: .cleaning),
        .init(name: "tshirt", aliases: ["laundry", "clothes", "wash"], group: .cleaning),
        .init(name: "tshirt.fill", aliases: ["laundry", "clothes", "wash"], group: .cleaning),
        .init(name: "drop", aliases: ["water", "liquid", "plumbing"], group: .cleaning),
        .init(name: "drop.fill", aliases: ["water", "liquid", "plumbing"], group: .cleaning),
        .init(name: "humidifier", aliases: ["mist", "humidity"], group: .cleaning),
        .init(name: "humidifier.and.droplets", aliases: ["mist", "humidity"], group: .cleaning),
        .init(name: "dehumidifier", aliases: ["dry", "humidity"], group: .cleaning),
        .init(name: "aqi.low", aliases: ["air", "quality"], group: .cleaning),
        .init(name: "aqi.medium", aliases: ["air", "quality"], group: .cleaning),
        .init(name: "aqi.high", aliases: ["air", "quality"], group: .cleaning),

        // MARK: Appliances
        .init(name: "washer", aliases: ["laundry", "clothes", "wash"], group: .appliances),
        .init(name: "washer.fill", aliases: ["laundry", "clothes", "wash"], group: .appliances),
        .init(name: "dryer", aliases: ["laundry", "clothes"], group: .appliances),
        .init(name: "dryer.fill", aliases: ["laundry", "clothes"], group: .appliances),
        .init(name: "refrigerator", aliases: ["fridge", "kitchen", "cold"], group: .appliances),
        .init(name: "refrigerator.fill", aliases: ["fridge", "kitchen", "cold"], group: .appliances),
        .init(name: "oven", aliases: ["kitchen", "bake"], group: .appliances),
        .init(name: "oven.fill", aliases: ["kitchen", "bake"], group: .appliances),
        .init(name: "stove", aliases: ["kitchen", "range", "cooktop"], group: .appliances),
        .init(name: "stove.fill", aliases: ["kitchen", "range", "cooktop"], group: .appliances),
        .init(name: "microwave", aliases: ["kitchen", "heat"], group: .appliances),
        .init(name: "microwave.fill", aliases: ["kitchen", "heat"], group: .appliances),
        .init(name: "dishwasher", aliases: ["kitchen", "wash", "dishes"], group: .appliances),
        .init(name: "dishwasher.fill", aliases: ["kitchen", "wash", "dishes"], group: .appliances),
        .init(name: "fan", aliases: ["hvac", "blow", "cool"], group: .appliances),
        .init(name: "fan.fill", aliases: ["hvac", "blow", "cool"], group: .appliances),
        .init(name: "fan.ceiling", aliases: ["ceiling fan", "hvac"], group: .appliances),
        .init(name: "air.conditioner.horizontal", aliases: ["ac", "hvac", "cool"], group: .appliances),
        .init(name: "heater.vertical", aliases: ["heat", "radiator", "hvac"], group: .appliances),
        .init(name: "water.waves", aliases: ["pool", "hot tub", "water"], group: .appliances),

        // MARK: Outdoor & Garden
        .init(name: "leaf", aliases: ["plant", "garden", "nature"], group: .outdoor),
        .init(name: "leaf.fill", aliases: ["plant", "garden", "nature"], group: .outdoor),
        .init(name: "tree", aliases: ["yard", "outdoor"], group: .outdoor),
        .init(name: "tree.fill", aliases: ["yard", "outdoor"], group: .outdoor),
        .init(name: "camera.macro", aliases: ["flower", "plant", "bug"], group: .outdoor),
        .init(name: "carrot", aliases: ["garden", "veggie", "plant"], group: .outdoor),
        .init(name: "carrot.fill", aliases: ["garden", "veggie", "plant"], group: .outdoor),
        .init(name: "moon", aliases: ["night", "evening"], group: .outdoor),
        .init(name: "moon.fill", aliases: ["night", "evening"], group: .outdoor),
        .init(name: "cloud", aliases: ["weather", "overcast"], group: .outdoor),
        .init(name: "cloud.fill", aliases: ["weather", "overcast"], group: .outdoor),
        .init(name: "sunset", aliases: ["evening", "dusk"], group: .outdoor),
        .init(name: "umbrella", aliases: ["rain", "weather", "patio"], group: .outdoor),
        .init(name: "umbrella.fill", aliases: ["rain", "weather", "patio"], group: .outdoor),
        .init(name: "laurel.leading", aliases: ["plant", "hedge", "shrub"], group: .outdoor),
        .init(name: "ladybug", aliases: ["bug", "pest"], group: .outdoor),
        .init(name: "ant", aliases: ["bug", "pest"], group: .outdoor),
        .init(name: "dog", aliases: ["pet"], group: .outdoor),
        .init(name: "dog.fill", aliases: ["pet"], group: .outdoor),
        .init(name: "cat", aliases: ["pet"], group: .outdoor),
        .init(name: "cat.fill", aliases: ["pet"], group: .outdoor),
        .init(name: "bird", aliases: ["pet", "feeder"], group: .outdoor),
        .init(name: "bird.fill", aliases: ["pet", "feeder"], group: .outdoor),
        .init(name: "pawprint", aliases: ["pet"], group: .outdoor),
        .init(name: "sun.max", aliases: ["sunny", "summer"], group: .outdoor),
        .init(name: "sun.max.fill", aliases: ["sunny", "summer"], group: .outdoor),
        .init(name: "cloud.rain", aliases: ["rain", "weather", "wet"], group: .outdoor),
        .init(name: "cloud.rain.fill", aliases: ["rain", "weather", "wet"], group: .outdoor),
        .init(name: "snowflake", aliases: ["snow", "winter", "cold", "ice"], group: .outdoor),
        .init(name: "thermometer.medium", aliases: ["temperature", "heat", "weather"], group: .outdoor),
        .init(name: "thermometer.sun", aliases: ["hot", "summer", "heat"], group: .outdoor),
        .init(name: "thermometer.snowflake", aliases: ["cold", "winter"], group: .outdoor),
        .init(name: "wind", aliases: ["air", "breeze", "weather"], group: .outdoor),
        .init(name: "tornado", aliases: ["wind", "storm"], group: .outdoor),
        .init(name: "flame", aliases: ["fire", "gas", "burn", "chimney"], group: .outdoor),
        .init(name: "flame.fill", aliases: ["fire", "gas", "burn", "chimney"], group: .outdoor),
        .init(name: "car", aliases: ["vehicle", "driveway", "auto"], group: .outdoor),
        .init(name: "car.fill", aliases: ["vehicle", "driveway", "auto"], group: .outdoor),
        .init(name: "bicycle", aliases: ["bike"], group: .outdoor),
        .init(name: "tent", aliases: ["camping", "outdoor"], group: .outdoor),
        .init(name: "figure.walk", aliases: ["person", "walk", "exercise"], group: .outdoor),
        .init(name: "figure.run", aliases: ["person", "run", "exercise"], group: .outdoor),

        // MARK: Utilities
        .init(name: "bolt", aliases: ["electrical", "electricity", "power"], group: .utilities),
        .init(name: "bolt.fill", aliases: ["electrical", "electricity", "power"], group: .utilities),
        .init(name: "bolt.circle", aliases: ["electrical", "power"], group: .utilities),
        .init(name: "poweroutlet.type.b", aliases: ["outlet", "plug", "electrical"], group: .utilities),
        .init(name: "poweroutlet.type.b.fill", aliases: ["outlet", "plug", "electrical"], group: .utilities),
        .init(name: "switch.2", aliases: ["switch", "toggle"], group: .utilities),
        .init(name: "cable.connector", aliases: ["wire", "cable"], group: .utilities),
        .init(name: "wifi", aliases: ["internet", "network"], group: .utilities),
        .init(name: "antenna.radiowaves.left.and.right", aliases: ["signal", "network"], group: .utilities),
        .init(name: "gauge.medium", aliases: ["meter", "pressure"], group: .utilities),
        .init(name: "speedometer", aliases: ["meter", "performance"], group: .utilities),
        .init(name: "battery.100", aliases: ["power", "charge"], group: .utilities),
        .init(name: "battery.25", aliases: ["power", "low"], group: .utilities),
        .init(name: "shield", aliases: ["safety", "protection"], group: .utilities),
        .init(name: "shield.fill", aliases: ["safety", "protection"], group: .utilities),
        .init(name: "shield.checkered", aliases: ["safety", "protection"], group: .utilities),
        .init(name: "lock", aliases: ["security", "locked"], group: .utilities),
        .init(name: "lock.fill", aliases: ["security", "locked"], group: .utilities),
        .init(name: "key", aliases: ["lock", "unlock"], group: .utilities),
        .init(name: "key.fill", aliases: ["lock", "unlock"], group: .utilities),
        .init(name: "alarm", aliases: ["clock", "timer"], group: .utilities),
        .init(name: "alarm.fill", aliases: ["clock", "timer"], group: .utilities),
        .init(name: "bell", aliases: ["notification", "alert"], group: .utilities),
        .init(name: "bell.fill", aliases: ["notification", "alert"], group: .utilities),
        .init(name: "smoke", aliases: ["detector", "alarm", "fire"], group: .utilities),
        .init(name: "fire.extinguisher", aliases: ["fire", "safety"], group: .utilities),
        .init(name: "cross.case", aliases: ["first aid", "medical", "kit"], group: .utilities),
        .init(name: "cross.case.fill", aliases: ["first aid", "medical", "kit"], group: .utilities),
        .init(name: "stethoscope", aliases: ["medical", "health"], group: .utilities),
        .init(name: "eye", aliases: ["watch", "monitor", "camera"], group: .utilities),
        .init(name: "eye.fill", aliases: ["watch", "monitor", "camera"], group: .utilities),

        // MARK: Lifestyle
        .init(name: "cart", aliases: ["shopping", "buy"], group: .lifestyle),
        .init(name: "cart.fill", aliases: ["shopping", "buy"], group: .lifestyle),
        .init(name: "bag", aliases: ["shopping"], group: .lifestyle),
        .init(name: "bag.fill", aliases: ["shopping"], group: .lifestyle),
        .init(name: "shippingbox", aliases: ["box", "package", "moving", "storage"], group: .lifestyle),
        .init(name: "shippingbox.fill", aliases: ["box", "package", "moving", "storage"], group: .lifestyle),
        .init(name: "gift", aliases: ["present", "package"], group: .lifestyle),
        .init(name: "gift.fill", aliases: ["present", "package"], group: .lifestyle),
        .init(name: "dollarsign.circle", aliases: ["money", "cost", "budget"], group: .lifestyle),
        .init(name: "dollarsign.circle.fill", aliases: ["money", "cost", "budget"], group: .lifestyle),
        .init(name: "creditcard", aliases: ["payment", "card"], group: .lifestyle),
        .init(name: "creditcard.fill", aliases: ["payment", "card"], group: .lifestyle),
        .init(name: "banknote", aliases: ["money", "cash"], group: .lifestyle),
        .init(name: "calendar", aliases: ["date", "schedule"], group: .lifestyle),
        .init(name: "calendar.badge.clock", aliases: ["schedule", "recurring"], group: .lifestyle),
        .init(name: "clock", aliases: ["time", "schedule"], group: .lifestyle),
        .init(name: "clock.fill", aliases: ["time", "schedule"], group: .lifestyle),
        .init(name: "timer", aliases: ["timing"], group: .lifestyle),
        .init(name: "hourglass", aliases: ["wait", "time"], group: .lifestyle),
        .init(name: "map", aliases: ["location", "travel"], group: .lifestyle),
        .init(name: "mappin.and.ellipse", aliases: ["location", "pin", "place"], group: .lifestyle),
        .init(name: "camera", aliases: ["photo", "picture"], group: .lifestyle),
        .init(name: "camera.fill", aliases: ["photo", "picture"], group: .lifestyle),
        .init(name: "photo", aliases: ["picture", "image"], group: .lifestyle),
        .init(name: "photo.fill", aliases: ["picture", "image"], group: .lifestyle),
        .init(name: "tv", aliases: ["television", "media"], group: .lifestyle),
        .init(name: "headphones", aliases: ["audio", "music"], group: .lifestyle),
        .init(name: "music.note", aliases: ["audio", "song"], group: .lifestyle),
        .init(name: "heart", aliases: ["favorite", "love"], group: .lifestyle),
        .init(name: "heart.fill", aliases: ["favorite", "love"], group: .lifestyle),
        .init(name: "star", aliases: ["favorite", "rating"], group: .lifestyle),
        .init(name: "star.fill", aliases: ["favorite", "rating"], group: .lifestyle),
        .init(name: "person", aliases: ["someone", "user"], group: .lifestyle),
        .init(name: "person.fill", aliases: ["someone", "user"], group: .lifestyle),
        .init(name: "person.2", aliases: ["family", "couple"], group: .lifestyle),
        .init(name: "person.2.fill", aliases: ["family", "couple"], group: .lifestyle),
        .init(name: "person.3", aliases: ["family", "group", "household"], group: .lifestyle),
        .init(name: "person.3.fill", aliases: ["family", "group", "household"], group: .lifestyle),
        .init(name: "book", aliases: ["read", "study"], group: .lifestyle),
        .init(name: "book.fill", aliases: ["read", "study"], group: .lifestyle),
        .init(name: "book.closed", aliases: ["read", "study"], group: .lifestyle),
        .init(name: "book.closed.fill", aliases: ["read", "study"], group: .lifestyle),

        // MARK: Misc
        .init(name: "wrench", aliases: ["repair", "fix"], group: .misc),
        .init(name: "wrench.fill", aliases: ["repair", "fix"], group: .misc),
        .init(name: "gearshape", aliases: ["settings", "config"], group: .misc),
        .init(name: "gearshape.fill", aliases: ["settings", "config"], group: .misc),
        .init(name: "gearshape.2", aliases: ["settings", "mechanical"], group: .misc),
        .init(name: "checkmark.circle", aliases: ["done", "complete", "check"], group: .misc),
        .init(name: "checkmark.circle.fill", aliases: ["done", "complete", "check"], group: .misc),
        .init(name: "xmark.circle", aliases: ["cancel", "remove"], group: .misc),
        .init(name: "exclamationmark.triangle", aliases: ["warning", "alert", "caution"], group: .misc),
        .init(name: "exclamationmark.triangle.fill", aliases: ["warning", "alert", "caution"], group: .misc),
        .init(name: "exclamationmark.circle", aliases: ["warning", "alert"], group: .misc),
        .init(name: "info.circle", aliases: ["info", "help"], group: .misc),
        .init(name: "questionmark.circle", aliases: ["help", "unknown"], group: .misc),
        .init(name: "flag", aliases: ["mark", "priority"], group: .misc),
        .init(name: "flag.fill", aliases: ["mark", "priority"], group: .misc),
        .init(name: "tag", aliases: ["label"], group: .misc),
        .init(name: "tag.fill", aliases: ["label"], group: .misc),
        .init(name: "bookmark", aliases: ["save"], group: .misc),
        .init(name: "bookmark.fill", aliases: ["save"], group: .misc),
        .init(name: "magnifyingglass", aliases: ["search", "find"], group: .misc),
        .init(name: "note", aliases: ["memo"], group: .misc),
        .init(name: "note.text", aliases: ["memo", "notes"], group: .misc),
        .init(name: "doc", aliases: ["document", "file", "paper"], group: .misc),
        .init(name: "doc.fill", aliases: ["document", "file", "paper"], group: .misc),
        .init(name: "doc.text", aliases: ["document", "paper", "file"], group: .misc),
        .init(name: "folder", aliases: ["directory", "files"], group: .misc),
        .init(name: "folder.fill", aliases: ["directory", "files"], group: .misc),
        .init(name: "folder.badge.plus", aliases: ["new folder", "admin"], group: .misc),
        .init(name: "folder.badge.gearshape", aliases: ["admin", "manage"], group: .misc),
        .init(name: "archivebox", aliases: ["archive", "storage"], group: .misc),
        .init(name: "archivebox.fill", aliases: ["archive", "storage"], group: .misc),
        .init(name: "tray", aliases: ["inbox"], group: .misc),
        .init(name: "tray.fill", aliases: ["inbox"], group: .misc),
        .init(name: "tray.2", aliases: ["inbox", "stack"], group: .misc),
        .init(name: "tray.2.fill", aliases: ["inbox", "stack"], group: .misc),
        .init(name: "tray.full", aliases: ["inbox", "mail"], group: .misc),
        .init(name: "tray.full.fill", aliases: ["inbox", "mail"], group: .misc),
        .init(name: "doc.on.doc", aliases: ["copy", "documents"], group: .misc),
        .init(name: "doc.text.fill", aliases: ["document", "paper"], group: .misc),
        .init(name: "envelope", aliases: ["mail", "letter", "admin"], group: .misc),
        .init(name: "envelope.fill", aliases: ["mail", "letter", "admin"], group: .misc),
        .init(name: "mail", aliases: ["envelope", "admin"], group: .misc),
        .init(name: "mail.fill", aliases: ["envelope", "admin"], group: .misc),
        .init(name: "paperplane", aliases: ["send", "mail"], group: .misc),
        .init(name: "paperplane.fill", aliases: ["send", "mail"], group: .misc),
        .init(name: "printer", aliases: ["print", "admin"], group: .misc),
        .init(name: "printer.fill", aliases: ["print", "admin"], group: .misc),
        .init(name: "scanner", aliases: ["scan", "admin"], group: .misc),
        .init(name: "scanner.fill", aliases: ["scan", "admin"], group: .misc),
        .init(name: "signature", aliases: ["sign", "admin"], group: .misc),
        .init(name: "pencil", aliases: ["write", "edit"], group: .misc),
        .init(name: "pencil.and.outline", aliases: ["edit", "annotate"], group: .misc),
        .init(name: "list.clipboard", aliases: ["checklist", "admin"], group: .misc),
        .init(name: "list.clipboard.fill", aliases: ["checklist", "admin"], group: .misc),
        .init(name: "list.bullet.clipboard", aliases: ["checklist", "admin"], group: .misc),
        .init(name: "list.bullet.clipboard.fill", aliases: ["checklist", "admin"], group: .misc),
        .init(name: "checklist", aliases: ["tasks", "admin"], group: .misc),
        .init(name: "checklist.checked", aliases: ["tasks", "done"], group: .misc),
        .init(name: "phone", aliases: ["call", "contact"], group: .misc),
        .init(name: "phone.fill", aliases: ["call", "contact"], group: .misc),
        .init(name: "message", aliases: ["text", "chat"], group: .misc),
        .init(name: "message.fill", aliases: ["text", "chat"], group: .misc),
        .init(name: "link", aliases: ["url", "chain"], group: .misc),
        .init(name: "arrow.clockwise", aliases: ["refresh", "cycle", "recurring"], group: .misc),
        .init(name: "arrow.triangle.2.circlepath", aliases: ["repeat", "cycle"], group: .misc),
    ]

    /// Match icons by substring on name or any alias; returns up to `limit` results.
    /// Empty query returns all icons (caller decides whether to display).
    static func search(_ query: String, limit: Int = 120) -> [CatalogIcon] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(icons.prefix(limit)) }
        let matches = icons.filter { icon in
            icon.name.lowercased().contains(q) ||
            icon.aliases.contains { $0.lowercased().contains(q) }
        }
        return Array(matches.prefix(limit))
    }
}
