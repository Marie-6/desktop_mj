// DesktopMJ — Little MJ lives in a pixel studio on your screen, making music.
// He grows through 9 looks, loves orange juice, and visits Muscles, Bubbles and Louie.
// Build: ./build.sh   Run: ./DesktopMJ   (menu bar 🎤, or right-click him, for drinks, friends and more)
// Real songs: put audio files (mp3, m4a, wav, mp4…) in ./songs, named after a song in his era's list
// (e.g. "Thriller.mp4"); he sings the ones that match the outfit he's wearing when you record.
import AppKit
import AVFoundation
import Carbon.HIToolbox
import QuartzCore

// MARK: - Pixel canvas

let S: CGFloat = 3 // screen points per sprite pixel
typealias Sprite = [[Character]]

func hex(_ v: UInt32) -> NSColor {
    NSColor(calibratedRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
            blue: CGFloat(v & 255) / 255, alpha: 1)
}

struct Canvas {
    let w: Int, h: Int
    var g: Sprite
    init(_ w: Int, _ h: Int) { self.w = w; self.h = h; g = Array(repeating: Array(repeating: ".", count: w), count: h) }

    mutating func px(_ x: Int, _ y: Int, _ c: Character) { if x >= 0, y >= 0, x < w, y < h { g[y][x] = c } }
    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: Character) {
        for yy in y..<y + rh { for xx in x..<x + rw { px(xx, yy, c) } }
    }
    // Mirror a rect around the vertical centre line (for the right arm, etc).
    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: Character, right: Bool) {
        rect(right ? w - x - rw : x, y, rw, rh, c)
    }
    mutating func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: Character) {
        for y in 0..<h { for x in 0..<w {
            let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1 { g[y][x] = c }
        } }
    }
    // Recolour cells of one colour where the pattern says so (prints, sequins, curls).
    mutating func pattern(_ from: Character, _ to: Character, _ hit: (Int, Int) -> Bool) {
        for y in 0..<h { for x in 0..<w where g[y][x] == from && hit(x, y) { g[y][x] = to } }
    }
    // Black outline around everything, like the reference art.
    mutating func outline() {
        let src = g
        for y in 0..<h { for x in 0..<w where src[y][x] == "." {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                if nx >= 0, ny >= 0, nx < w, ny < h, src[ny][nx] != ".", src[ny][nx] != "K" { g[y][x] = "K"; break }
            }
        } }
    }
}

func drawGrid(_ g: Sprite, _ pal: [Character: NSColor], at o: NSPoint, flipped: Bool = false) {
    let h = g.count, w = g[0].count
    for r in 0..<h { for col in 0..<w {
        guard let color = pal[g[r][col]] else { continue }
        color.setFill()
        let x = flipped ? w - 1 - col : col
        NSRect(x: o.x + CGFloat(x) * S, y: o.y + CGFloat(h - 1 - r) * S, width: S, height: S).fill()
    } }
}

let ink = hex(0x1a1018)

func drawBubble(_ text: String, centerX: CGFloat, bottom: CGFloat, width: CGFloat, lo: CGFloat = 2) {
    let font = NSFont(name: "Menlo-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    // wrap onto more lines when the line wouldn't fit in the visible space
    let room = max(60, width - lo - 2 - 14)
    let size = (text as NSString).boundingRect(with: NSSize(width: room, height: 200), options: .usesLineFragmentOrigin, attributes: attrs).size
    var r = NSRect(x: centerX - ceil(size.width) / 2 - 7, y: bottom + 7, width: ceil(size.width) + 14, height: ceil(size.height) + 8)
    r.origin.x = max(lo, min(width - r.width - 2, r.origin.x))
    let body = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: centerX - 5, y: r.minY + 1))
    tail.line(to: NSPoint(x: centerX, y: bottom))
    tail.line(to: NSPoint(x: centerX + 5, y: r.minY + 1))
    ink.set(); body.lineWidth = 4; body.stroke(); tail.lineWidth = 4; tail.stroke()
    NSColor.white.set(); body.fill(); tail.fill()
    (text as NSString).draw(with: NSRect(x: r.minX + 7, y: r.minY + 4, width: ceil(size.width) + 1, height: ceil(size.height)),
                            options: .usesLineFragmentOrigin, attributes: attrs)
}

struct Particle { var text: String; var x, y, vx, vy: CGFloat; var life: Int; var color: NSColor }

func drawParticles(_ ps: [Particle]) {
    for p in ps {
        let a: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 15),
                                                .foregroundColor: p.color.withAlphaComponent(min(1, CGFloat(p.life) / 25))]
        (p.text as NSString).draw(at: NSPoint(x: p.x, y: p.y), withAttributes: a)
    }
}

// MARK: - Little MJ's 9 looks

struct Look { let name: String; let year: String; let songs: [String]; var unlockedAt: Int? = nil } // unlockedAt: an extra outfit, not a stage of his own; wearable once he reaches that era

let looks: [Look] = [
    Look(name: "Little Mike", year: "1969", songs: ["ABC", "I Want You Back", "Ben", "Rockin' Robin"]),
    Look(name: "Off the Wall", year: "1979", songs: ["Rock with You", "Off the Wall", "Don't Stop 'Til You Get Enough"]),
    Look(name: "Thriller", year: "1982", songs: ["Thriller", "Beat It", "Wanna Be Startin' Somethin'"]),
    Look(name: "Billie Jean", year: "1983", songs: ["Billie Jean", "Human Nature", "P.Y.T."]),
    Look(name: "Bad", year: "1987", songs: ["Bad", "The Way You Make Me Feel", "Man in the Mirror"]),
    Look(name: "Smooth Criminal", year: "1988", songs: ["Smooth Criminal", "Dirty Diana", "Leave Me Alone"]),
    Look(name: "Dangerous", year: "1991", songs: ["Black or White", "Remember the Time", "Jam", "Dangerous"]),
    Look(name: "HIStory", year: "1996", songs: ["Scream", "Earth Song", "They Don't Care About Us", "You Are Not Alone", "HIStory"]),
    Look(name: "Invincible", year: "2001", songs: ["You Rock My World", "This Is It", "Butterflies", "Whatever Happens", "Threatened", "Don't Walk Away"]),
    // tour and extra outfits
    Look(name: "Thriller Era", year: "1983", songs: ["Thriller", "Billie Jean", "Beat It", "Wanna Be Startin' Somethin'"], unlockedAt: 2),
    Look(name: "Invincible Era", year: "2001", songs: ["You Rock My World", "Butterflies", "Cry", "Unbreakable", "Whatever Happens", "Threatened", "Don't Walk Away"], unlockedAt: 8),
    Look(name: "Dangerous World Tour", year: "1992", songs: ["Jam", "Dangerous", "Remember the Time", "Black or White", "Heal the World"], unlockedAt: 6),
    Look(name: "HIStory World Tour", year: "1996", songs: ["Scream", "They Don't Care About Us", "Earth Song", "Stranger in Moscow"], unlockedAt: 7),
    Look(name: "Thriller Era · Blue Uniform", year: "1983", songs: ["Thriller", "Billie Jean", "Beat It", "Wanna Be Startin' Somethin'"], unlockedAt: 2),
    Look(name: "HIStory World Tour · Opening Suit", year: "1996", songs: ["Scream", "They Don't Care About Us", "Earth Song", "Stranger in Moscow"], unlockedAt: 7),
]

// Each look is the artwork from the reference image (looks/look1…9.png), drawn exactly as-is.
let spriteH: CGFloat = 112
let lookDir = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
    .resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent("looks")
let eraCount = looks.firstIndex { $0.unlockedAt != nil } ?? looks.count // the stages he grows through
func isUnlocked(_ i: Int, stage: Int) -> Bool { i <= stage || (looks[i].unlockedAt.map { $0 <= stage } ?? false) }
let lookImages: [NSImage] = (1...looks.count).map { i in
    guard let img = NSImage(contentsOf: lookDir.appendingPathComponent("look\(i).png")) else {
        FileHandle.standardError.write("Missing looks/look\(i).png next to DesktopMJ\n".data(using: .utf8)!); exit(1)
    }
    return img
}

// Poses are motion only (hop, waddle, bounce) so his appearance never changes.
enum Pose: Hashable { case stand, back, toe(mirror: Bool), walkA, walkB, cheer, point, pointL, lean, sad, signature, held, rest, side(left: Bool, step: Int), drink(Int), zombie(Int), zombieSide(left: Bool, step: Int) }

// Each look's signature dance pose, cut from the poses reference image (looks/pose1…9.png).
// …and how he looks while you hold him up with the mouse (looks/held1…9.png).
func loadArt(_ name: String) -> [NSImage] {
    (1...looks.count).map { i in
        guard let img = NSImage(contentsOf: lookDir.appendingPathComponent("\(name)\(i).png")) else {
            FileHandle.standardError.write("Missing looks/\(name)\(i).png next to DesktopMJ\n".data(using: .utf8)!); exit(1)
        }
        return img
    }
}
let poseImages = loadArt("pose"), heldImages = loadArt("held"), restImages = loadArt("rest") // rest = napping
// Peeking from a screen edge. Looks 1, 3, 5, 7, 8 peek from the left edge in the art, 2, 4, 6, 9 from the right;
// the other edge uses the same art mirrored.
let peekImages = loadArt("peek")
func peekArtFacesLeftEdge(_ i: Int) -> Bool { [0, 2, 4, 6, 7, 9, 11, 13].contains(i) }
let sideLeft = loadArt("sideL"), sideRight = loadArt("sideR") // walking sideways
// Hand-drawn moonwalk for a look, if there is one (looks/moonL8-1.png …): 1 = the glide, 2 = feet together, up on a toe.
// Frame 2 is optional (a look without one holds the glide); the tour outfits' frame 2 is their glide with the legs slid together.
let moonFrames: [(left: [NSImage], right: [NSImage])?] = (1...looks.count).map { i in
    func f(_ side: String, _ n: Int) -> NSImage? { NSImage(contentsOf: lookDir.appendingPathComponent("moon\(side)\(i)-\(n).png")) }
    guard let l1 = f("L", 1), let r1 = f("R", 1) else { return nil }
    return ([l1, f("L", 2) ?? l1], [r1, f("R", 2) ?? r1])
}
let backImages = loadArt("back") // seen from behind, for spins
// Toe stand that ends a spin or moonwalk (looks/toe1…9.png). Optional: a look without one keeps its old ending.
let toeImages: [NSImage?] = (1...looks.count).map { NSImage(contentsOf: lookDir.appendingPathComponent("toe\($0).png")) }
// Mirrored dance pose and toe stand: the body is flipped but the head (hair, curls, hat) stays exactly as drawn
// (looks/poseM…, toeM…). Optional: a look whose arm touches its head has none, and doesn't mirror.
func loadMirrored(_ name: String) -> [NSImage?] { (1...looks.count).map { NSImage(contentsOf: lookDir.appendingPathComponent("\(name)M\($0).png")) } }
let poseMirrored = loadMirrored("pose"), toeMirrored = loadMirrored("toe")
// Picked up with sunglasses on, drawn with them (looks/heldS…). Optional per look.
let heldWithGlasses: [[NSImage?]] = ["S"].map { g in (1...looks.count).map { NSImage(contentsOf: lookDir.appendingPathComponent("held\(g)\($0).png")) } }
// Zombie dance (looks/zombie3-1.png, zombie3-2.png): optional, so far just Thriller.
let zombieFrames: [[NSImage]?] = (1...looks.count).map { i in
    let f = (1...2).compactMap { NSImage(contentsOf: lookDir.appendingPathComponent("zombie\(i)-\($0).png")) }
    return f.count == 2 ? f : nil
}

// MARK: - Closet: extras he wears over any outfit (looks/acc-*.png, drawn at the size of a 157 px wide head)

struct Closet: Codable { var glasses = 0, hat = 0, bat = false, pumpkin = false } // glasses/hat: 0 = none
let closetKey = "DesktopMJ.closet"
var closet = (UserDefaults.standard.data(forKey: closetKey)).flatMap { try? JSONDecoder().decode(Closet.self, from: $0) }
    .map { c -> Closet in var c = c; if c.glasses > 1 { c.glasses = 0 }; return c } ?? Closet() { // the cool shades (2) are gone
    didSet { if !CommandLine.arguments.contains("--preview"), let d = try? JSONEncoder().encode(closet) { UserDefaults.standard.set(d, forKey: closetKey) } }
}
// Side views drawn with one closet item on (looks/sideDecL…/sideDecR…, padded by sidePad on every side so they
// line up with the plain side drawing), and the item each one shows. Thriller's is its zombie walk instead.
enum DecItem { case glasses(Int), hat(Int), pumpkin, bat }
let sideDecItems: [DecItem?] = [.hat(2), .glasses(1), nil, .glasses(1), .pumpkin, .glasses(1), .hat(1), .hat(2), .bat, nil, nil, nil, nil, nil, nil]
let sidePad: CGFloat = 80
func loadSides(_ name: String) -> [(left: NSImage, right: NSImage)?] {
    (1...looks.count).map { i in
        guard let l = NSImage(contentsOf: lookDir.appendingPathComponent("\(name)L\(i).png")),
              let r = NSImage(contentsOf: lookDir.appendingPathComponent("\(name)R\(i).png")) else { return nil }
        return (l, r)
    }
}
let sideDecImages = loadSides("sideDec"), zombieSides = loadSides("zombieSide"), zombieSunSides = loadSides("zombieSun") // zombieSun: the shuffle in sunglasses
let sideSunImages = loadSides("sideSun") // side walk in sunglasses, for every look that has them
// Which of his own side drawings fits what he's wearing right now (sunglasses first), and the item it shows.
func sideDrawing(_ i: Int) -> (images: (left: NSImage, right: NSImage), item: DecItem)? {
    if closet.glasses == 1, let s = sideSunImages[i] { return (s, .glasses(1)) }
    if let item = sideDecWorn(i), let d = sideDecImages[i] { return (d, item) }
    return nil
}
func sideDecWorn(_ i: Int) -> DecItem? {
    guard sideDecImages[i] != nil, let item = sideDecItems[i] else { return nil }
    switch item {
    case .glasses(let g): return closet.glasses == g ? item : nil
    case .hat(let h): return closet.hat == h ? item : nil
    case .pumpkin: return closet.pumpkin ? item : nil
    case .bat: return closet.bat ? item : nil
    }
}
let glassesNames = ["None", "😎 Sunglasses"], hatNames = ["None", "🎉 Party hat", "✨ Star hat"]
func accImage(_ n: String) -> NSImage? { NSImage(contentsOf: lookDir.appendingPathComponent("acc-\(n).png")) }
let glassesImages = [nil, accImage("glasses1")], hatImages = [nil, accImage("hat1"), accImage("hat2")]
let batImage = accImage("bat"), pumpkinImage = accImage("pumpkin")
let accHeadW: CGFloat = 157

// Where the head is in a drawing, found from the pixels (image units, measured from the top-left):
// the middle and width of the hair near the top, and, when he faces us, the middle of his two eyes.
struct HeadInfo { var cx: CGFloat = 0, top: CGFloat = 0, w: CGFloat = 0, eyes: NSPoint? = nil }
var headCache: [ObjectIdentifier: HeadInfo] = [:]
func pixels(_ img: NSImage) -> ([UInt8], Int, Int)? { // premultiplied RGBA, top row first
    guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    var px = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
    guard let ctx = CGContext(data: &px, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    return (px, cg.width, cg.height)
}
func headInfo(_ img: NSImage, look: Int? = nil) -> HeadInfo {
    if let h = headCache[ObjectIdentifier(img)] { return h }
    var info = HeadInfo()
    defer { headCache[ObjectIdentifier(img)] = info }
    guard let (px, W, H) = pixels(img) else { return info }
    let u = img.size.width / CGFloat(W)
    func a(_ x: Int, _ y: Int) -> Int { Int(px[(y * W + x) * 4 + 3]) }
    var top = -1, centres: [Int] = [], widths: [Int] = []
    for y in 0..<H {
        var lo = W, hi = -1
        for x in 0..<W where a(x, y) > 100 { lo = min(lo, x); hi = max(hi, x) }
        guard hi >= 0 else { continue }
        if top < 0 { top = y }
        if y - top > H * 3 / 10 { break }
        if y - top > H / 20 { centres.append(lo + hi); widths.append(hi - lo + 1) }
    }
    guard top >= 0, !centres.isEmpty else { return info }
    centres.sort(); widths.sort()
    let cx = CGFloat(centres[centres.count / 2]) / 2, hw = CGFloat(widths[widths.count * 9 / 10])
    info = HeadInfo(cx: cx * u, top: CGFloat(top) * u, w: hw * u)
    // eyes: find this look's own eyes (from its main drawing, where the rig marks them) in this drawing
    guard let i = look else { return info }
    let rig = rigs[i], ref = img === lookImages[i] ? nil : pixels(lookImages[i])
    if ref == nil { // the main drawing itself
        let e = rig.eyes; info.eyes = NSPoint(x: (e[0].midX + e[1].midX) / 2, y: (e[0].midY + e[1].midY) / 2); return info
    }
    guard let (rp, RW, RH) = ref, RW > 0, RH > 0 else { return info }
    let ru = lookImages[i].size.width / CGFloat(RW)
    func find(_ e: NSRect) -> (NSPoint, Int)? {
        let ex = Int(e.minX / ru), ey = Int(e.minY / ru), ew = Int(e.width / ru), eh = Int(e.height / ru)
        guard ex >= 0, ey >= 0, ex + ew <= RW, ey + eh <= RH else { return nil }
        var best = (cost: Int.max, x: 0, y: 0)
        let y0 = max(0, top), y1 = min(H - eh, top + Int(hw)), x0 = max(0, Int(cx - hw / 2)), x1 = min(W - ew, Int(cx + hw / 2))
        guard y1 > y0, x1 > x0 else { return nil }
        for y in y0..<y1 { for x in x0..<x1 {
            var c = 0
            for ty in stride(from: 0, to: eh, by: 1) {
                let a0 = ((y + ty) * W + x) * 4, b0 = ((ey + ty) * RW + ex) * 4
                for t in 0..<(ew * 4) { c += abs(Int(px[a0 + t]) - Int(rp[b0 + t])) }
                if c >= best.cost { break }
            }
            if c < best.cost { best = (c, x, y) }
        } }
        return (NSPoint(x: CGFloat(best.x) + CGFloat(ew) / 2, y: CGFloat(best.y) + CGFloat(eh) / 2), best.cost / max(1, ew * eh * 4))
    }
    guard let (l, lc) = find(rig.eyes[0]), let (r, rc) = find(rig.eyes[1]), lc < 45, rc < 45,
          abs(l.y - r.y) < hw * 0.08, r.x - l.x > hw * 0.15 else {
        // eyes drawn differently here (surprised, squinting): same spot under the hair as in the main drawing
        let main = headInfo(lookImages[i], look: i), e = main.eyes!
        info.eyes = NSPoint(x: info.cx + (e.x - main.cx) * info.w / main.w, y: info.top + (e.y - main.top) * info.w / main.w)
        return info
    }
    info.eyes = NSPoint(x: (l.x + r.x) / 2 * u, y: (l.y + r.y) / 2 * u)
    return info
}

// In a side view: his one eye (where this look's own eye drawing fits best on the face), and which way he faces.
var sideEyeCache: [ObjectIdentifier: (eye: NSRect, facesLeft: Bool)?] = [:]
func sideEye(_ img: NSImage, look i: Int) -> (eye: NSRect, facesLeft: Bool)? {
    if let c = sideEyeCache[ObjectIdentifier(img)] { return c }
    // a few drawings where hair or a hat brim fools the matcher: marked by hand (look, moonL/moonR, eye rect, faces left)
    func moon(_ l: Int, _ left: Bool) -> [NSImage] { moonFrames[l].map { left ? $0.left : $0.right } ?? [] }
    let marked: [([NSImage], NSRect, Bool)] = [
        (moon(2, false), R(90, 84, 26, 22), false), (moon(4, true), R(47, 81, 26, 29), true), (moon(5, true), R(50, 82, 24, 28), true),
        ([sideLeft[3]], R(39, 79, 26, 30), true), ([sideRight[3]], R(102, 82, 27, 27), false),
        (moon(3, true), R(40, 79, 26, 28), true), (moon(3, false), R(101, 82, 28, 26), false),
        (moon(10, true), R(45, 86, 20, 23), true), (moon(10, false), R(99, 86, 20, 23), false),
    ]
    for (imgs, eye, facesLeft) in marked where imgs.contains(where: { $0 === img }) {
        sideEyeCache[ObjectIdentifier(img)] = (eye, facesLeft); return (eye, facesLeft)
    }
    var out: (eye: NSRect, facesLeft: Bool)? = nil
    defer { sideEyeCache[ObjectIdentifier(img)] = out }
    guard let (px, W, H) = pixels(img), let (rp, RW, _) = pixels(lookImages[i]) else { return nil }
    let u = img.size.width / CGFloat(W), ru = lookImages[i].size.width / CGFloat(RW), h = headInfo(img)
    let top = Int(h.top / u), hw = Int(h.w / u), cx = Int(h.cx / u)
    func skin(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < W, y >= 0, y < H else { return false }
        let i = (y * W + x) * 4, al = Int(px[i + 3]); guard al > 200 else { return false }
        let r = Int(px[i]) * 255 / al, g = Int(px[i + 1]) * 255 / al, b = Int(px[i + 2]) * 255 / al
        return r > 150 && r > b + 25 && g > 80 && g > b - 10 && r - g < 120
    }
    var best = (avg: Double.infinity, x: 0, y: 0, w: 0, h: 0) // average difference per colour value
    for e in rigs[i].eyes {
        let ex = Int(e.minX / ru), ey = Int(e.minY / ru), ew = Int(e.width / ru), eh = Int(e.height / ru), n = ew * eh * 4
        for y in max(0, top + hw / 4)..<max(0, min(H - eh - 4, top + hw)) { for x in max(4, cx - hw / 2)..<max(4, min(W - ew - 4, cx + hw / 2)) {
            // an eye sits in the face: skin just under it, and in front of or behind it
            guard skin(x + ew / 2, y + eh + 2) || skin(x + ew / 3, y + eh + 2) || skin(x + ew * 2 / 3, y + eh + 2),
                  skin(x - 3, y + eh / 2) || skin(x + ew + 2, y + eh / 2) else { continue }
            var c = 0, cap = best.avg.isFinite ? Int(best.avg * Double(n)) : Int.max
            for ty in 0..<eh {
                let a0 = ((y + ty) * W + x) * 4, b0 = ((ey + ty) * RW + ex) * 4
                for t in 0..<(ew * 4) { c += abs(Int(px[a0 + t]) - Int(rp[b0 + t])) }
                if c >= cap { break }
            }
            if c < cap { best = (Double(c) / Double(n), x, y, ew, eh); cap = c }
        } }
    }
    guard best.w > 0, best.avg < 60 else { return nil }
    let eye = NSRect(x: CGFloat(best.x) * u, y: CGFloat(best.y) * u, width: CGFloat(best.w) * u, height: CGFloat(best.h) * u)
    out = (eye, eye.midX < h.cx)
    return out
}
// Glasses come in one size, the one that fits Thriller.
enum GlassesSize { // worked out the first time they're needed (the rigs aren't set up yet up here)
    // each outfit's art is drawn at its own scale, so convert Thriller's image units into this outfit's
    // a smaller head than Thriller's gets smaller glasses (never bigger: a big afro doesn't mean a bigger face)
    // Billie Jean, Bad, Smooth Criminal and Dangerous have shorter, narrower faces under their hair or hat
    static func unit(_ i: Int) -> CGFloat {
        if i >= 9 { return 0.8 } // the tour outfits: narrow faces under big hair
        return [3, 4, 5, 6].contains(i) ? 0.85 : min(1, heads[i] / heads[2])
    }
    static let heads: [CGFloat] = (0..<looks.count).map { headInfo(lookImages[$0], look: $0).w }
    static let headW = headInfo(lookImages[2], look: 2).w
}
let sidePoses: Set<Int> = [5] // Smooth Criminal's lean is drawn side-on, so it gets the side-on shades
// Side-on shades: the same sunglasses as his hand-drawn side walks.
func drawSideGlasses(_ p: NSImage, _ i: Int, in r: NSRect) {
    guard closet.glasses > 0, let (e, left) = sideEye(p, look: i) else { return }
    drawnStyleSunglasses(e, left, in: r, d: r.width / p.size.width, scale: GlassesSize.unit(i))
}

// Sunglasses on a side walk that has no drawing of them (the tour outfits): the same shades as the hand-drawn
// sideSun walks, measured off Thriller's. A wide flat lens over the eye and half an eye further forward,
// a stepped grey shine at the front top, and a thick arm back into the hair.
func drawnStyleSunglasses(_ e: NSRect, _ left: Bool, in r: NSRect, d: CGFloat, scale: CGFloat) {
    func at(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: r.minX + x * d, y: r.maxY - y * d) }
    func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSRect { // image units, either way round
        let a = at(min(x0, x1), max(y0, y1)), b = at(max(x0, x1), min(y0, y1)); return NSRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y) }
    let back = left ? e.maxX + e.width * 0.08 : e.minX - e.width * 0.08, front = back + (left ? -1 : 1) * e.width * 1.54 * scale // narrower faces get narrower shades, as from the front
    let lensW = abs(back - front), lensH = lensW * 0.7 // Thriller's proportions, whatever shape the eye is drawn
    let top = e.midY - lensH * 0.4, bottom = e.midY + lensH * 0.6, dir: CGFloat = left ? 1 : -1 // dir: from the front towards the back
    let ink = NSColor(white: 0.03, alpha: 1)
    ink.setFill() // the arm, back to the ear
    box(back - dir * 2, top, back + dir * e.width * 1.0, top + lensH * 0.24).fill()
    let lens = box(front, top, back, bottom), path = NSBezierPath(roundedRect: lens, xRadius: lens.height * 0.12, yRadius: lens.height * 0.12)
    ink.setFill(); path.fill()
    NSColor(white: 0.13, alpha: 1).setFill() // the lens inside a dark rim
    NSBezierPath(roundedRect: lens.insetBy(dx: max(1, 1.6 * d), dy: max(1, 1.6 * d)), xRadius: lens.height * 0.08, yRadius: lens.height * 0.08).fill()
    NSColor(white: 0.5, alpha: 1).setFill() // the shine, stepped like the drawing
    box(front + dir * lensW * 0.08, top + lensH * 0.08, front + dir * lensW * 0.42, top + lensH * 0.32).fill()
    box(front + dir * lensW * 0.08, top + lensH * 0.32, front + dir * lensW * 0.24, top + lensH * 0.6).fill()
}

// Puts on what he's wearing from the closet: picture `p` was just drawn into `r`.
func drawCloset(_ p: NSImage, _ look: Int, in r: NSRect, glasses: Bool = true, pumpkin: Bool = true, hat: Bool = true) {
    guard closet.glasses > 0 || closet.hat > 0 || closet.pumpkin else { return }
    let h = headInfo(p, look: glasses ? look : nil), d = r.width / p.size.width, s = h.w / accHeadW * d // image units → points; accessory art → points
    guard h.w > 0 else { return }
    func at(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: r.minX + x * d, y: r.maxY - y * d) }
    NSGraphicsContext.current?.imageInterpolation = .none
    if pumpkin, closet.pumpkin, let pk = pumpkinImage { // trick-or-treat bucket at his side
        let pw = pk.size.width * s * 0.62, ph = pk.size.height * s * 0.62
        pk.draw(in: NSRect(x: at(h.cx, 0).x + h.w * d * 0.36, y: r.minY, width: pw, height: ph))
    }
    if glasses, let e = h.eyes, let g = glassesImages[closet.glasses] {
        let gs = GlassesSize.headW / accHeadW * d * GlassesSize.unit(look) // the same size on screen for every outfit
        let gw = g.size.width * gs, gh = g.size.height * gs, c = at(e.x, e.y)
        g.draw(in: NSRect(x: c.x - gw / 2, y: c.y - gh / 2, width: gw, height: gh))
    }
    if hat, let hat = hatImages[closet.hat] { // perched on top, tipped a little to one side
        let hw = hat.size.width * s, hh = hat.size.height * s, base = at(h.cx + h.w * 0.08, h.top + hat.size.height * h.w / accHeadW * 0.22)
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform(); t.translateX(by: base.x, yBy: base.y); t.rotate(byDegrees: -12); t.concat()
        hat.draw(in: NSRect(x: -hw / 2, y: 0, width: hw, height: hh))
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.current?.imageInterpolation = .high
}
// A little bat friend flapping round his head.
func drawBat(midX: CGFloat, width w: CGFloat, behind: Bool) {
    guard closet.bat, let b = batImage else { return }
    let t = CACurrentMediaTime(), a = t * 1.7
    guard (sin(a) > 0) == behind else { return }
    let flap: CGFloat = Int(t * 9) % 2 == 0 ? 1 : 0.45, bw = b.size.width * 0.3, bh = b.size.height * 0.3 * flap
    let c = NSPoint(x: midX + CGFloat(cos(a)) * w * 0.62, y: spriteH * 0.86 + CGFloat(sin(a * 2)) * 6)
    NSGraphicsContext.current?.imageInterpolation = .none
    b.draw(in: NSRect(x: c.x - bw / 2, y: c.y - bh / 2, width: bw, height: bh), from: .zero, operation: .sourceOver, fraction: behind ? 0.8 : 1)
    NSGraphicsContext.current?.imageInterpolation = .high
}

let drinkPalette: [Character: NSColor] = [
    "K": 0x1a1018, "J": 0xff9a1f, "j": 0xffd27a, "g": 0xcfe8f5, "C": 0xd8141c, "Q": 0x1e4fd6, "q": 0xf0f0f6, "R": 0xe0243a,
].mapValues(hex)

func makeDrink(_ k: Int) -> Sprite {
    var c = Canvas(6, 9)
    switch k {
    case 0: c.rect(1, 1, 4, 7, "g"); c.rect(1, 3, 4, 5, "J"); c.px(2, 4, "j")            // orange juice glass
    case 1: c.rect(1, 1, 4, 7, "C"); c.rect(1, 1, 4, 1, "q"); c.rect(1, 4, 4, 1, "q")   // Coke can
    default: c.rect(1, 1, 4, 7, "Q"); c.rect(1, 1, 4, 1, "q"); c.rect(1, 4, 4, 1, "q"); c.rect(1, 3, 4, 1, "R") // Pepsi can
    }
    c.outline(); return c.g
}
let drinkSprites = (0..<3).map(makeDrink)

// MARK: - Rig: where the eyes, arms and legs are in each look (image pixels, measured from the top-left)

struct Rig {
    let eyes: [NSRect]
    let armL: NSRect?, armR: NSRect? // a hanging arm, sleeve and hand; nil when it isn't hanging (Billie Jean's glove)
    let legTop: CGFloat, legLeft: CGFloat, legSplit: CGFloat, legRight: CGFloat
}

func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: y, width: w, height: h) }

let rigs: [Rig] = [
    Rig(eyes: [R(50, 96, 23, 27), R(96, 96, 25, 27)], armL: R(30, 150, 21, 38), armR: R(117, 150, 20, 38), legTop: 189, legLeft: 40, legSplit: 81, legRight: 124),
    Rig(eyes: [R(50, 95, 23, 28), R(100, 95, 23, 28)], armL: R(34, 155, 19, 31), armR: R(115, 155, 19, 31), legTop: 188, legLeft: 45, legSplit: 85, legRight: 127),
    Rig(eyes: [R(45, 93, 23, 28), R(95, 93, 23, 28)], armL: R(28, 150, 23, 37), armR: R(110, 150, 24, 37), legTop: 188, legLeft: 38, legSplit: 80, legRight: 122),
    Rig(eyes: [R(50, 88, 23, 23), R(100, 88, 23, 23)], armL: nil, armR: R(106, 128, 31, 53), legTop: 182, legLeft: 42, legSplit: 85, legRight: 127),
    Rig(eyes: [R(45, 100, 28, 19), R(100, 100, 26, 19)], armL: R(30, 150, 23, 38), armR: R(118, 150, 23, 38), legTop: 189, legLeft: 40, legSplit: 81, legRight: 122),
    Rig(eyes: [R(50, 100, 23, 19), R(102, 100, 26, 19)], armL: R(34, 150, 22, 33), armR: R(115, 150, 23, 33), legTop: 184, legLeft: 44, legSplit: 87, legRight: 130),
    Rig(eyes: [R(40, 100, 28, 19), R(93, 100, 28, 19)], armL: R(26, 150, 27, 38), armR: R(110, 150, 26, 38), legTop: 189, legLeft: 36, legSplit: 80, legRight: 122),
    Rig(eyes: [R(35, 89, 30, 23), R(93, 89, 31, 23)], armL: R(23, 150, 24, 34), armR: R(112, 150, 24, 34), legTop: 181, legLeft: 36, legSplit: 80, legRight: 122),
    Rig(eyes: [R(50, 100, 23, 19), R(102, 100, 26, 19)], armL: R(42, 150, 19, 33), armR: R(115, 150, 19, 33), legTop: 184, legLeft: 42, legSplit: 85, legRight: 130),
    Rig(eyes: [R(40, 94, 28, 16), R(93, 94, 27, 16)], armL: R(28, 148, 24, 32), armR: R(106, 148, 25, 32), legTop: 184, legLeft: 35, legSplit: 79, legRight: 122),
    Rig(eyes: [R(39, 92, 29, 15), R(94, 92, 30, 15)], armL: R(26, 148, 24, 32), armR: R(110, 148, 25, 32), legTop: 184, legLeft: 34, legSplit: 80, legRight: 125),
    Rig(eyes: [R(37, 94, 29, 14), R(93, 94, 30, 14)], armL: R(26, 148, 24, 34), armR: R(106, 148, 25, 34), legTop: 184, legLeft: 33, legSplit: 78, legRight: 123),
    Rig(eyes: [R(43, 96, 27, 14), R(96, 96, 28, 14)], armL: R(32, 148, 24, 32), armR: R(111, 148, 25, 32), legTop: 184, legLeft: 40, legSplit: 84, legRight: 127),
    Rig(eyes: [R(40, 94, 28, 16), R(93, 94, 27, 16)], armL: R(28, 148, 24, 32), armR: R(106, 148, 25, 32), legTop: 184, legLeft: 35, legSplit: 79, legRight: 122), // Thriller Era's, recoloured
    Rig(eyes: [R(43, 96, 27, 14), R(96, 96, 28, 14)], armL: R(32, 148, 24, 32), armR: R(111, 148, 25, 32), legTop: 184, legLeft: 40, legSplit: 84, legRight: 127), // HIStory World Tour's, recoloured
]

// Skin colour between the eyes, used for eyelids when he blinks.
let skinColors: [NSColor] = lookImages.enumerated().map { i, img in
    let e = rigs[i].eyes
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let c = rep.colorAt(x: Int((e[0].maxX + e[1].minX) / 2), y: Int(e[0].midY)) else { return hex(0xf0a070) }
    return c
}

// How each part is moved this frame: lifted feet, closed eyes, a drink held up, or the signature pose art.
struct Frame { var liftL: CGFloat = 0, liftR: CGFloat = 0, blink = false, drink: Int? = nil, signature = false, held = false, rest = false, back = false, toe: Bool? = nil, mirror = false, moon = false, side: (left: Bool, step: Int)? = nil, zombie: Int? = nil }

func drawMJ(_ i: Int, _ f: Frame, at o: NSPoint, height: CGFloat) {
    let img = lookImages[i], rig = rigs[i], ih = img.size.height, k = height / ih
    let full = NSRect(x: o.x, y: o.y, width: img.size.width * k, height: height)
    guard let ctx = NSGraphicsContext.current else { return }
    ctx.imageInterpolation = .high
    let sunWalk = closet.glasses == 1 && sideSunImages[i] != nil && f.zombie == nil // in sunglasses he moonwalks in his sunglasses walk drawing
    if let sd = f.side, f.moon, !sunWalk, let mf = moonFrames[i] { // moonwalking, with this look's own moonwalk drawings
        let p = (sd.left ? mf.left : mf.right)[sd.step % 2], pw = p.size.width * k
        let r = NSRect(x: full.midX - pw / 2, y: o.y + 2 * k, width: pw, height: p.size.height * k)
        p.draw(in: r); drawSideGlasses(p, i, in: r); drawCloset(p, i, in: r, glasses: false)
        return
    }
    if let z = f.zombie, f.side == nil, let zf = zombieFrames[i] { // zombie dance
        let p = zf[z % 2], pw = p.size.width * k, r = NSRect(x: full.midX - pw / 2, y: o.y + 2 * k, width: pw, height: p.size.height * k)
        p.draw(in: r); drawCloset(p, i, in: r)
        return
    }
    if let sd = f.side { // side view: the feet take turns stepping forward
        let p = (sd.left ? sideLeft : sideRight)[i], pw = p.size.width * k, ph = p.size.height * k
        let r = NSRect(x: full.midX - pw / 2, y: o.y + 2 * k + (sd.step % 2 == 0 ? 0 : 1), width: pw, height: ph)
        // his own drawing of this side with the item on (or Thriller's zombie walk), drawn over the same spot
        let own = f.zombie == nil ? sideDrawing(i) : nil, worn = own?.item
        let zombieSun = f.zombie != nil && closet.glasses == 1 ? zombieSunSides[i] : nil // the shuffle in sunglasses, worn like his side walk
        let drawn = (f.zombie != nil ? zombieSun ?? zombieSides[i] : own?.images).map { sd.left ? $0.left : $0.right }
        let q = drawn ?? p, qr = drawn == nil ? r : r.insetBy(dx: -sidePad * k, dy: -sidePad * k)
        let feet = ph * 0.12, stride: CGFloat = sd.step % 2 == 0 ? 2 : -2
        ctx.saveGraphicsState(); NSBezierPath(rect: NSRect(x: r.minX - 80, y: r.minY + feet, width: pw + 160, height: ph + 80)).addClip()
        q.draw(in: qr); ctx.restoreGraphicsState()
        ctx.saveGraphicsState(); NSBezierPath(rect: NSRect(x: r.minX - 80, y: r.minY - 2, width: pw + 160, height: feet + 2)).addClip()
        q.draw(in: qr.offsetBy(dx: stride, dy: 0)); ctx.restoreGraphicsState()
        var shades = zombieSun == nil, hat = true, pumpkin = true
        switch worn { case .glasses?: shades = false; case .hat?: hat = false; case .pumpkin?: pumpkin = false; default: break }
        if shades { drawSideGlasses(p, i, in: r) }
        drawCloset(p, i, in: r, glasses: false, pumpkin: pumpkin, hat: hat)
        return
    }
    if let mirror = f.toe, let toe = toeImages[i] { // toe stand, mirrored to match the way he moonwalked
        let p = (mirror ? toeMirrored[i] : nil) ?? toe, pw = p.size.width * k
        let r = NSRect(x: full.midX - pw / 2, y: o.y + 2 * k, width: pw, height: p.size.height * k)
        p.draw(in: r); drawCloset(p, i, in: r)
        return
    }
    if f.signature || f.held || f.rest || f.back { // pose art is drawn whole, at the same scale, standing on the same spot
        let mirrored = f.mirror && f.signature ? poseMirrored[i] : nil
        let drawnShades = f.held && closet.glasses > 0 ? heldWithGlasses[closet.glasses - 1][i] : nil
        let p = mirrored ?? drawnShades ?? (f.back ? backImages : f.rest ? restImages : f.held ? heldImages : poseImages)[i], pw = p.size.width * k
        let r = NSRect(x: full.midX - pw / 2, y: o.y + 2 * k, width: pw, height: p.size.height * k)
        p.draw(in: r)
        let profile = f.signature && sidePoses.contains(i) // a pose where his face is seen from the side
        if profile { drawSideGlasses(p, i, in: r) }
        if !f.rest { drawCloset(p, i, in: r, glasses: !f.back && drawnShades == nil && !profile, pumpkin: !f.held) } // napping, he takes it all off
        return
    }
    func v(_ r: NSRect) -> NSRect { NSRect(x: o.x + r.minX * k, y: o.y + (ih - r.maxY) * k, width: r.width * k, height: r.height * k) }
    let legs = [(R(rig.legLeft, rig.legTop, rig.legSplit - rig.legLeft, ih - rig.legTop), f.liftL),
                (R(rig.legSplit, rig.legTop, rig.legRight - rig.legSplit, ih - rig.legTop), f.liftR)]
    // Drinking: the hand at the end of the arm bends up to his chest, still attached at the sleeve.
    var hand: NSRect?
    if f.drink != nil, let a = rig.armR { hand = R(a.minX, a.maxY - a.height * 0.45, a.width, a.height * 0.45) }
    let handUp = (hand?.height ?? 0) * 0.9, handIn: CGFloat = 4

    ctx.saveGraphicsState()
    let clip = NSBezierPath(rect: full)
    for (r, lift) in legs where lift != 0 { clip.append(NSBezierPath(rect: v(r))) }
    if let h = hand { clip.append(NSBezierPath(rect: v(h))) }
    clip.windingRule = .evenOdd; clip.addClip()
    img.draw(in: full)
    ctx.restoreGraphicsState()
    for (r, lift) in legs where lift != 0 {
        ctx.saveGraphicsState()
        NSBezierPath(rect: v(r).offsetBy(dx: 0, dy: lift * k)).addClip()
        img.draw(in: full.offsetBy(dx: 0, dy: lift * k))
        ctx.restoreGraphicsState()
    }
    if let h = hand, let d = f.drink {
        ink.setFill(); v(R(h.minX + 2, h.minY, h.width - 4, 2)).fill() // cuff edge where the hand left
        let dx = -handIn * k, dy = handUp * k
        drawGrid(drinkSprites[d], drinkPalette, at: NSPoint(x: v(h).midX + dx - 9, y: v(h).maxY + dy - 8))
        ctx.saveGraphicsState()
        NSBezierPath(rect: v(h).offsetBy(dx: dx, dy: dy)).addClip()
        img.draw(in: full.offsetBy(dx: dx, dy: dy))
        ctx.restoreGraphicsState()
    }
    if f.blink {
        for e in rig.eyes {
            skinColors[i].setFill(); v(e).fill()
            ink.setFill(); NSRect(x: v(e).minX, y: v(e).minY + v(e).height * 0.3, width: v(e).width, height: 2.5 * k).fill()
        }
    }
    drawCloset(img, i, in: full)
}

func frameFor(_ pose: Pose, blink: Bool, gulp: Bool = false) -> Frame {
    var f = Frame(); f.blink = blink
    switch pose {
    case .walkA: f.liftL = 4
    case .walkB: f.liftR = 4
    case .cheer, .point, .pointL, .lean, .signature: f.signature = true; f.blink = false
    case .held: f.held = true; f.blink = false
    case .back: f.back = true; f.blink = false
    case .toe(let mirror): f.toe = mirror; f.blink = false
    case .rest: f.rest = true; f.blink = false
    case .side(let left, let step): f.side = (left, step)
    case .drink(let k): f.drink = k; f.blink = gulp
    case .zombie(let n): f.zombie = n; f.blink = false
    case .zombieSide(let left, let step): f.side = (left, step); f.zombie = 0; f.blink = false
    default: break
    }
    return f
}

// MARK: - Friends

struct FriendInfo { let name: String; let kind: String; let emoji: String; let hello: String; let lines: [String]; let mjLines: [String]; let tune: [Int] }

let friends: [FriendInfo] = [
    FriendInfo(name: "Muscles", kind: "snake", emoji: "🐍", hello: "Ssss… ♥", lines: ["Hsss ♪", "*wraps around Mike*", "Ssssmooth!"],
               mjLines: ["Who's a good snake?", "Muscles, you're shining today!", "Wanna hear my new song?"], tune: [52, 55, 52, 50]),
    FriendInfo(name: "Bubbles", kind: "chimp", emoji: "🐒", hello: "Ook ook! ♥", lines: ["*does the moonwalk*", "Eee-eee! ♪", "*steals Mike's hat*"],
               mjLines: ["Let's dance, Bubbles!", "Hee-hee! You've got the moves!", "Bubbles, my best friend!"], tune: [76, 79, 76, 81]),
    FriendInfo(name: "Louie", kind: "llama", emoji: "🦙", hello: "Mwehh! ♥", lines: ["*happy llama noises*", "Mwaaa~ ♪", "*nibbles Mike's hair*"],
               mjLines: ["Louie, you look fabulous!", "Want some hay, Louie?", "That's a groovy bow!"], tune: [64, 62, 60, 67]),
]

let friendPalette: [Character: NSColor] = [
    "K": 0x1a1018, "E": 0x140c12, "W": 0xffffff, "R": 0xe0243a, "B": 0xf29a9a,
    "g": 0x45b13f, "v": 0x2d7f2b, "y": 0xd8e27a,
    "u": 0x6b4226, "i": 0xe0b48a, "s": 0x8a5a3a,
    "l": 0xf3e9d2, "k": 0xd8c6a2, "M": 0xff5fa8, "Y": 0xffd83a,
].mapValues(hex)

func makeFriend(_ kind: Int, frame: Int) -> Sprite {
    switch kind {
    case 0: // Muscles the snake, coiled with his head up
        var c = Canvas(26, 16)
        c.ellipse(11, 12.2, 9.5, 2.9, "g")
        c.ellipse(11, 9.4, 7.8, 2.4, "K"); c.ellipse(11, 9.4, 7, 2, "g")
        c.ellipse(10, 6.9, 5.4, 2, "K"); c.ellipse(10, 6.9, 4.6, 1.6, "g")
        c.rect(14, 3, 3, 5, "g"); c.rect(15, 1, 6, 4, "g"); c.px(15, 1, "."); c.px(20, 1, ".")
        c.pattern("g", "v") { x, y in (x + y * 2) % 5 == 0 }
        c.rect(14, 4, 1, 4, "y"); c.px(18, 2, "E"); c.px(19, 4, "E")
        if frame == 1 { c.px(21, 3, "R"); c.px(22, 3, "R"); c.px(23, 2, "R"); c.px(23, 4, "R") }
        c.outline(); return c.g
    case 1: // Bubbles the chimp, in his little red shirt
        var c = Canvas(20, 24)
        c.ellipse(3.5, 7, 2.2, 2.2, "u"); c.ellipse(16.5, 7, 2.2, 2.2, "u"); c.px(3, 7, "i"); c.px(16, 7, "i")
        c.ellipse(10, 6.5, 6, 5.6, "u"); c.ellipse(10, 8.2, 4.4, 3.6, "i"); c.rect(7, 5, 6, 1, "i")
        c.px(8, 6, "E"); c.px(12, 6, "E"); c.px(9, 9, "s"); c.px(11, 9, "s"); c.rect(8, 10, 5, 1, "E")
        c.px(6, 8, "B"); c.px(14, 8, "B")
        c.rect(6, 13, 9, 6, "R"); c.px(10, 15, "W"); c.px(10, 17, "W")
        c.rect(3, 13, 3, 1, "u"); c.rect(3, 14, 2, 6, "u"); c.rect(3, 20, 2, 1, "i")
        if frame == 1 { c.rect(15, 8, 4, 7, "K"); c.rect(16, 9, 2, 5, "u"); c.rect(16, 7, 2, 2, "i"); c.rect(15, 13, 1, 1, "u") }
        else { c.rect(15, 13, 2, 1, "u"); c.rect(15, 14, 2, 6, "u"); c.rect(15, 20, 2, 1, "i") }
        c.rect(6, 19, 3, 3, "u"); c.rect(12, 19, 3, 3, "u"); c.rect(5, 22, 4, 1, "i"); c.rect(12, 22, 4, 1, "i")
        c.outline(); return c.g
    default: // Louie the llama, with a pink bow
        var c = Canvas(22, 26)
        c.rect(13, 1, 1, 3, "l"); c.rect(16, 1, 1, 3, "l")
        c.rect(12, 3, 7, 5, "l"); c.rect(17, 5, 4, 3, "k"); c.px(20, 5, "E"); c.px(15, 5, "E"); c.px(19, 7, "E")
        c.rect(12, 8, 5, 8, "l"); c.rect(2, 13, 15, 7, "l"); c.rect(1, 13, 2, 3, "l")
        c.pattern("l", "k") { x, y in y > 8 && (x * 3 + y * 2) % 7 == 0 }
        c.rect(5, 13, 8, 3, "M"); c.pattern("M", "Y") { x, y in y == 15 && x % 2 == 0 }
        c.rect(12, 10, 5, 1, "M"); c.rect(13, 9, 3, 3, "M"); c.px(14, 10, "Y")
        let legs = frame == 1 ? [(3, 0), (6, 1), (11, 0), (14, 1)] : [(3, 1), (6, 0), (11, 1), (14, 0)]
        for (x, up) in legs { c.rect(x, 20, 2, 4 - up, "l"); c.rect(x, 24 - up, 2, 1, "u") }
        c.outline(); return c.g
    }
}

// MARK: - Sound (tiny chiptune synth, no audio files needed)

final class Synth {
    var muted = UserDefaults.standard.bool(forKey: "DesktopMJ.muted")
    private var playing: [NSSound] = []
    let rate = 22050.0

    func voice(_ seq: [(Int, Double)], bpm: Double, vol: Float, duty: Double = 0.5) -> [Float] {
        let beat = 60 / bpm
        var out: [Float] = []
        for (m, beats) in seq {
            let n = Int(beats * beat * rate)
            if m <= 0 { out += [Float](repeating: 0, count: n); continue }
            let f = 440 * pow(2, Double(m - 69) / 12)
            for i in 0..<n {
                let ph = (Double(i) * f / rate).truncatingRemainder(dividingBy: 1)
                let env = Float(1 - 0.8 * Double(i) / Double(n)) * min(1, Float(n - i) / 80)
                out.append((ph < duty ? vol : -vol) * env)
            }
        }
        return out
    }

    func play(_ voices: [[Float]]) {
        guard !muted else { return }
        let len = voices.map(\.count).max() ?? 0
        var mix = [Float](repeating: 0, count: len)
        for v in voices { for i in v.indices { mix[i] += v[i] } }
        var data = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + len * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        data.append(contentsOf: Array("data".utf8)); u32(UInt32(len * 2))
        for s in mix { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 30000))) }
        guard let snd = NSSound(data: data) else { return }
        playing.removeAll { !$0.isPlaying }
        playing.append(snd); snd.play()
    }

    func stop() { playing.forEach { $0.stop() }; playing.removeAll(); track?.stop(); track = nil }

    // Plays a random file from the songs folder next to the app, but only one named after a song
    // from his current era (e.g. "Thriller.mp4" for the Thriller look). Returns its length and title.
    private var track: AVAudioPlayer?
    func realSong(from titles: [String]) -> (secs: Double, title: String)? {
        guard !muted, let exe = Bundle.main.executableURL else { return nil }
        let dir = exe.resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent("songs")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in files.shuffled() {
            let name = url.deletingPathExtension().lastPathComponent
            guard let title = titles.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }),
                  let p = try? AVAudioPlayer(contentsOf: url), p.play() else { continue }
            track = p
            return (p.duration, title)
        }
        return nil
    }

    func jingle(_ notes: [Int], bpm: Double = 520, vol: Float = 0.12) {
        play([voice(notes.map { ($0, 1) }, bpm: bpm, vol: vol, duty: 0.25)])
    }

    // An original little groove in each era's mood. Returns its length in seconds.
    func song(stage: Int) -> Double {
        let roots = [60, 57, 57, 54, 57, 55, 59, 52, 57]
        let bpms: [Double] = [132, 118, 120, 117, 116, 126, 118, 114, 110]
        let scale = stage == 0 ? [0, 2, 4, 7, 9] : [0, 3, 5, 7, 10]
        let root = roots[stage], bpm = bpms[stage]
        var melody: [(Int, Double)] = [], idx = 5
        for i in 0..<32 {
            idx = max(0, min(9, idx + Int.random(in: -2...2)))
            let rest = i % 8 == 7 || Int.random(in: 0..<7) == 0
            melody.append((rest ? 0 : root + 12 + scale[idx % 5] + 12 * (idx / 5), 0.5))
        }
        let groove = [0, 0, 12, 0, 7, 0, 10, 12]
        let bass = (0..<32).map { (root - 24 + groove[$0 % 8] + ($0 / 8 == 2 ? 5 : 0), 0.5) }
        let hats: [(Int, Double)] = (0..<32).flatMap { $0 % 2 == 1 ? [(100, 0.06), (0, 0.44)] : [(0, 0.5)] }
        play([voice(melody, bpm: bpm, vol: 0.10, duty: 0.25), voice(bass, bpm: bpm, vol: 0.11), voice(hats, bpm: bpm, vol: 0.015)])
        return 16 * 60 / bpm
    }
}

// MARK: - Save data

struct Save: Codable {
    var stage = 0, look = 0, songs = 0, progress = 0, totalSongs = 0
    var happy = 80.0, juice = 80.0
    var last = Date()
    var lastSong = ""

    static let key = "DesktopMJ.save", historyKey = "DesktopMJ.hasHIStory"
    static func load() -> Save {
        let hadHIStory = UserDefaults.standard.bool(forKey: historyKey)
        UserDefaults.standard.set(true, forKey: historyKey)
        guard let d = UserDefaults.standard.data(forKey: key), var s = try? JSONDecoder().decode(Save.self, from: d) else { return Save() }
        let minutes = min(600, Date().timeIntervalSince(s.last) / 60) // he gets a bit thirsty while you're away
        s.juice = max(min(s.juice, 40), s.juice - minutes * 0.1); s.happy = max(min(s.happy, 45), s.happy - minutes * 0.05)
        s.juice = max(s.juice, 35); s.happy = max(s.happy, 40)
        if !hadHIStory { // HIStory was added as look 8, before Legend: a save from back then at Legend moves up one
            if s.stage == 7 { s.stage = 8 }
            if s.look == 7 { s.look = 8 }
            s.store()
        }
        if s.look >= looks.count { s.look = min(s.stage, eraCount - 1) } // an outfit that's since been taken out
        return s
    }
    func store() {
        var s = self; s.last = Date()
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Save.key) }
    }
}

let songsPerLook = 3

// MARK: - The studio (his home)

final class StudioView: NSView {
    weak var studio: Studio?
    var onClick: (() -> Void)?
    override func mouseUp(with e: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let studio else { return }
        let t = studio.t, on = studio.onAir
        func R(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) {
            hex(c).setFill()
            NSRect(x: CGFloat(x) * S, y: CGFloat(Studio.h - y - h) * S, width: CGFloat(w) * S, height: CGFloat(h) * S).fill()
        }
        func text(_ s: String, _ x: Int, _ y: Int, _ size: CGFloat, _ c: UInt32) {
            let a: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Menlo-Bold", size: size) ?? .boldSystemFont(ofSize: size), .foregroundColor: hex(c)]
            (s as NSString).draw(at: NSPoint(x: CGFloat(x) * S, y: CGFloat(Studio.h - y) * S), withAttributes: a)
        }
        if on && studio.thriller { drawGraveyard(t, R, text); return }
        // Room shell, walls and floor.
        R(0, 0, 92, 58, 0x1a1018); R(1, 1, 90, 2, 0x6a3a9a)
        R(1, 4, 90, 42, 0x3b2350)
        for x in stride(from: 4, to: 90, by: 6) { R(x, 4, 2, 42, 0x432a5a) }
        R(1, 46, 90, 11, 0x7a4a26); R(1, 46, 90, 1, 0x4a2a14)
        for row in 0..<3 { for i in 0..<11 { R(1 + i * 9 + (row % 2) * 4, 47 + row * 4, 1, 3, 0x5e3619) } }
        R(40, 50, 30, 6, 0x8a1a2c); R(41, 51, 28, 4, 0xd83a52)
        // Gold records: one for every look he has grown out of.
        for i in 0..<eraCount - 1 {
            let rx = 6 + i * 10, ry = 6
            R(rx, ry, 9, 11, 0x1a1018); R(rx + 1, ry + 1, 7, 9, 0x5a3d73)
            if i < studio.records {
                R(rx + 2, ry + 3, 5, 5, 0xf5c542); R(rx + 3, ry + 2, 3, 7, 0xf5c542); R(rx + 2, ry + 3, 1, 1, 0xfff1b0)
                R(rx + 4, ry + 5, 1, 1, 0x8a6a10)
            } else { R(rx + 4, ry + 5, 1, 1, 0x2a1838) }
            R(rx + 2, ry + 9, 5, 1, 0xc0c0c8)
        }
        // Neon sign and the ON AIR light.
        text("MIKE'S STUDIO", 32, 21, 10, on && (t / 8) % 2 == 0 ? 0xffffff : 0xff5fb0)
        R(72, 21, 17, 6, 0x1a1018); R(73, 22, 15, 4, on ? ((t / 10) % 2 == 0 ? 0xff2a3a : 0xc0182a) : 0x4a1a24)
        text("ON AIR", 74, 26, 7, on ? 0xffffff : 0x8a5a64)
        // Mixing desk with a screen.
        R(10, 20, 20, 9, 0x111118); R(11, 21, 18, 7, 0x0d2a1a)
        for i in 0..<18 {
            let a = on ? Int(abs(sin(Double(t + i * 5) / 5)) * 3) : 0
            R(11 + i, 24 - a, 1, 1 + 2 * a, 0x5cff8a)
        }
        R(18, 29, 4, 1, 0x333340)
        R(3, 30, 34, 3, 0x55556a); R(4, 33, 32, 13, 0x2b2b35)
        let caps: [UInt32] = [0xff5fb0, 0xf5c542, 0x5cc8ff, 0x5cff8a]
        for i in 0..<8 {
            R(6 + i * 4, 35, 1, 8, 0x111118)
            R(5 + i * 4, 36 + (on ? (t / 4 + i * 3) % 6 : (i * 2) % 6), 3, 1, caps[i % 4])
            R(5 + i * 4, 31, 2, 1, on && (t / 3 + i) % 3 == 0 ? 0x5cff8a : 0x2a5a3a)
        }
        // Mic stand.
        R(47, 29, 1, 17, 0xa0a0ac); R(44, 45, 7, 1, 0x55556a); R(46, 25, 3, 4, 0x45454f); R(46, 25, 3, 1, 0x9a9aa6)
        // A crate of oranges, his favourite.
        R(70, 41, 9, 5, 0x8a5a2a); R(70, 41, 9, 1, 0x6a4018)
        R(71, 39, 3, 2, 0xff9a1f); R(75, 39, 3, 2, 0xff8a1a); R(73, 37, 3, 2, 0xffaa33)
        // Speaker that thumps while recording.
        let thump = on && (t / 7) % 2 == 0 ? 1 : 0
        R(81, 27, 9, 19, 0x1d1d24); R(82 - thump, 29 - thump, 7 + 2 * thump, 7 + 2 * thump, 0x55556a); R(84, 31, 3, 3, 0x2b2b35)
        R(83, 38, 5, 5, 0x55556a); R(85, 40, 1, 1, 0x2b2b35)
    }
}

extension StudioView {
    // While he records "Thriller" the studio turns into the graveyard from the short film.
    func drawGraveyard(_ t: Int, _ R: (Int, Int, Int, Int, UInt32) -> Void, _ text: (String, Int, Int, CGFloat, UInt32) -> Void) {
        func fog(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ a: CGFloat) {
            hex(0xb8c4d8).withAlphaComponent(a).setFill()
            NSRect(x: CGFloat(x) * S, y: CGFloat(Studio.h - y - h) * S, width: CGFloat(w) * S, height: CGFloat(h) * S).fill(using: .sourceOver)
        }
        let flash = t % 420 < 4 || (t % 420 > 8 && t % 420 < 11) // lightning, twice in quick succession
        // Night sky, darker at the top.
        R(0, 0, 92, 58, 0x07060c)
        let sky: [UInt32] = flash ? [0x6a6a9a, 0x7a7aaa, 0x8a8ab8, 0x9a9ac6] : [0x0a0918, 0x110f24, 0x181530, 0x201a3a]
        for (i, c) in sky.enumerated() { R(1, 1 + i * 10, 90, 10, c) }
        for (i, (x, y)) in [(8, 4), (19, 9), (27, 3), (38, 7), (51, 4), (60, 11), (86, 13), (45, 15), (14, 16)].enumerated() {
            R(x, y, 1, 1, (t / 12 + i) % 5 == 0 ? 0x6a6a8a : 0xe8e8ff)
        }
        // Full moon with a cloud drifting across it.
        R(68, 4, 10, 10, 0xf2eccb); R(67, 6, 12, 6, 0xf2eccb); R(70, 3, 6, 12, 0xf2eccb)
        R(71, 6, 2, 2, 0xd8d0a8); R(74, 10, 3, 2, 0xd8d0a8); R(69, 9, 1, 1, 0xd8d0a8)
        let cx = 40 + (t / 6) % 70
        R(cx, 9, 14, 2, 0x2c2a44); R(cx + 3, 8, 8, 1, 0x2c2a44); R(cx - 2, 10, 4, 1, 0x2c2a44)
        // A bat flapping past the moon.
        let bx = 92 - (t / 2) % 120, by = 7 + Int(sin(Double(t) / 6) * 2)
        R(bx, by, 2, 1, 0x05040a); R(bx - 2, by - ((t / 4) % 2), 2, 1, 0x05040a); R(bx + 2, by - ((t / 4) % 2), 2, 1, 0x05040a)
        // The old house on the hill, one window flickering.
        R(1, 30, 30, 16, 0x0d0b16); R(4, 22, 18, 9, 0x0d0b16); R(6, 19, 14, 3, 0x0d0b16); R(9, 17, 8, 2, 0x0d0b16)
        R(17, 14, 3, 6, 0x0d0b16) // chimney
        R(8, 25, 3, 3, (t / 9) % 7 == 0 ? 0x3a2a10 : 0xf5c542); R(15, 25, 3, 3, 0x1a1626); R(12, 33, 3, 5, 0x1a1626)
        R(22, 32, 3, 3, (t / 13) % 5 == 0 ? 0xf5c542 : 0x2a2010)
        // A dead tree, branches reaching out.
        R(84, 18, 3, 30, 0x0d0b16); R(80, 22, 5, 1, 0x0d0b16); R(79, 20, 2, 2, 0x0d0b16); R(87, 25, 4, 1, 0x0d0b16)
        R(89, 23, 1, 2, 0x0d0b16); R(82, 28, 2, 1, 0x0d0b16); R(85, 15, 1, 3, 0x0d0b16); R(86, 16, 2, 1, 0x0d0b16)
        // Graveyard ground.
        R(1, 44, 90, 13, flash ? 0x2a3a2a : 0x141c14); R(1, 44, 90, 1, flash ? 0x3a5a3a : 0x1f2e1c)
        for x in stride(from: 2, to: 90, by: 5) { R(x, 43, 1, 1, 0x1f2e1c) }
        // Tombstones (clear of the mic spot, where Mike stands).
        let stone: UInt32 = flash ? 0x9a9aa8 : 0x5a5a68, dark: UInt32 = flash ? 0x6a6a78 : 0x3a3a46
        for (x, y, h) in [(5, 38, 8), (17, 40, 7), (29, 37, 9), (69, 39, 8), (79, 41, 6)] {
            R(x, y, 7, h, stone); R(x + 1, y - 1, 5, 1, stone); R(x + 6, y, 1, h, dark)
            R(x + 3, y + 2, 1, 4, dark); R(x + 2, y + 3, 3, 1, dark) // cross
            R(x - 1, y + h, 9, 1, 0x2a2018) // fresh dirt
        }
        R(39, 35, 2, 11, stone); R(37, 38, 6, 2, stone) // a big cross
        // Zombie hands clawing up out of the graves.
        for (i, x) in [12, 24, 76].enumerated() {
            let up = max(0, Int(sin(Double(t + i * 40) / 18) * 5))
            if up > 0 {
                R(x, 50 - up, 2, up, 0x5a7a4a)
                R(x - 1, 49 - up, 1, 2, 0x6a8a5a); R(x, 48 - up, 1, 2, 0x6a8a5a); R(x + 1, 48 - up, 1, 2, 0x6a8a5a); R(x + 2, 49 - up, 1, 2, 0x6a8a5a)
                R(x - 1, 50, 4, 1, 0x2a2018)
            }
        }
        // Low fog rolling across.
        for i in 0..<5 {
            let fx = (i * 23 + t / (3 + i % 2)) % 120 - 20
            fog(fx, 47 + (i % 3) * 3, 24, 2, 0.18); fog(fx + 4, 46 + (i % 3) * 3, 14, 1, 0.12)
        }
        // The title, dripping red.
        text("THRILLER", 33, 23, 16, flash ? 0xffffff : 0xd8141e)
        for (k, x) in [35, 40, 46, 51, 57].enumerated() {
            let d = (t / 5 + k * 7) % 12
            R(x, 22, 1, 1 + d / 3, 0xa00c14)
        }
    }
}

final class Studio {
    static let w = 92, h = 58
    let window: NSWindow
    let view = StudioView()
    var onAir = false, records = 0, t = 0
    var thriller = false // recording the real "Thriller": the room becomes the graveyard

    init(screen: NSRect) {
        let size = NSSize(width: CGFloat(Studio.w) * S, height: CGFloat(Studio.h) * S)
        window = NSWindow(contentRect: NSRect(origin: NSPoint(x: screen.maxX - size.width - 30, y: screen.minY), size: size),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        view.frame = NSRect(origin: .zero, size: size); view.studio = self
        window.contentView = view // hidden until you open it from the menu bar
    }
    var homeX: CGFloat { window.frame.minX + 58 * S } // where Mike stands at the mic
    var isOpen: Bool { window.isVisible }
    func tick() { t += 1; if t % 2 == 0 { view.needsDisplay = true } }
}

// MARK: - Friend visits

final class FriendView: NSView {
    weak var friend: Friend?
    override func draw(_ dirtyRect: NSRect) {
        guard let f = friend else { return }
        let g = makeFriendCached(f.kind, f.frame)
        let w = CGFloat(g[0].count) * S
        let o = NSPoint(x: (bounds.width - w) / 2, y: f.hop ? S : 0)
        NSGraphicsContext.current?.saveGraphicsState()
        drawGrid(g, friendPalette, at: o, flipped: f.flipped)
        drawParticles(f.particles)
        if let b = f.bubble { drawBubble(b.0, centerX: bounds.midX, bottom: CGFloat(g.count) * S + 4, width: bounds.width) }
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

var friendCache: [Int: Sprite] = [:]
func makeFriendCached(_ kind: Int, _ frame: Int) -> Sprite {
    if let s = friendCache[kind * 10 + frame] { return s }
    let s = makeFriend(kind, frame: frame); friendCache[kind * 10 + frame] = s; return s
}

final class Friend {
    let kind: Int
    let window: NSWindow
    let view = FriendView()
    let x: CGFloat
    var ticks = 0, frame = 0, hop = false, flipped = false, leaving = false, excited = false
    var bubble: (String, Int)?
    var particles: [Particle] = []
    static let winW: CGFloat = 220, winH: CGFloat = 26 * S + 60

    init(kind: Int, x: CGFloat, ground: CGFloat) {
        self.kind = kind; self.x = x
        window = NSWindow(contentRect: NSRect(x: x - Friend.winW / 2, y: ground, width: Friend.winW, height: Friend.winH),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.level = .floating; window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        view.frame = NSRect(x: 0, y: 0, width: Friend.winW, height: Friend.winH); view.friend = self
        window.contentView = view; window.alphaValue = 0
        window.orderFrontRegardless()
        spawn("✨", 4)
    }

    func say(_ s: String, _ ticks: Int = 75) { bubble = (s, ticks) }
    func spawn(_ s: String, _ n: Int, color: NSColor = .systemPink) {
        for i in 0..<n {
            particles.append(Particle(text: s, x: Friend.winW / 2 - 25 + CGFloat(i) * 14, y: 50, vx: .random(in: -0.3...0.3),
                                      vy: .random(in: 0.6...1.2), life: 50 + i * 8, color: color))
        }
    }
    func leave() { leaving = true; bubble = nil; spawn("✨", 3, color: .systemYellow) }

    // Returns false once it has faded away.
    func tick() -> Bool {
        ticks += 1
        window.alphaValue = leaving ? window.alphaValue - 0.05 : min(1, window.alphaValue + 0.06)
        if leaving && window.alphaValue <= 0 { window.orderOut(nil); return false }
        frame = (ticks / (excited ? 8 : 30)) % 2
        hop = excited && (ticks / 6) % 2 == 0
        if let b = bubble { bubble = b.1 > 1 ? (b.0, b.1 - 1) : nil }
        for i in particles.indices { particles[i].x += particles[i].vx; particles[i].y += particles[i].vy; particles[i].life -= 1 }
        particles.removeAll { $0.life <= 0 }
        view.needsDisplay = true
        return true
    }
}

// MARK: - Mike

enum Mode { case idle, walk, record, dance, drink, show, visit, rest, docked, held, falling }

// A coloured mood bar for the status menu.
final class MeterView: NSView {
    let icon: String, label: String, value: Double, color: NSColor
    init(_ icon: String, _ label: String, _ value: Double, _ color: NSColor) {
        self.icon = icon; self.label = label; self.value = value; self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.menuFont(ofSize: 0), attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let ty = (bounds.height - font.boundingRectForFont.height) / 2 + 1
        ("\(icon)  \(label)" as NSString).draw(at: NSPoint(x: 18, y: ty), withAttributes: attrs)
        let pct = "\(Int(value.rounded()))%" as NSString, pw = pct.size(withAttributes: attrs).width
        pct.draw(at: NSPoint(x: bounds.width - 16 - pw, y: ty), withAttributes: attrs)
        let track = NSRect(x: 106, y: bounds.midY - 5, width: bounds.width - 106 - 16 - 44, height: 10)
        NSColor.labelColor.withAlphaComponent(0.15).setFill(); NSBezierPath(roundedRect: track, xRadius: 5, yRadius: 5).fill()
        var fill = track; fill.size.width = track.width * CGFloat(max(0, min(100, value)) / 100)
        (value < 25 ? NSColor.systemRed : color).setFill(); NSBezierPath(roundedRect: fill, xRadius: 5, yRadius: 5).fill()
    }
}

// MARK: - Spin: three quick turns that speed up, then slow into a pose
let spinDur = 0.85, spinTurns = 3.0
func spinAngle(_ t: Double) -> Double {
    let u = min(1, max(0, t / spinDur)), e = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
    return e * spinTurns * 2 * .pi
}
// Which way he faces at this angle, and how far he is from facing it squarely (-0.5…0.5 of a quarter turn).
func spinView(_ a: Double) -> (pose: Pose, off: Double) {
    let q = a / (.pi / 2), n = q.rounded()
    let views: [Pose] = [.stand, .side(left: false, step: 0), .back, .side(left: true, step: 0)]
    return (views[Int(n) % 4], q - n)
}
// Swoosh rings around him: the back half goes behind the sprite, the front half in front. Strongest at top speed.
func drawSpinLines(angle a: Double, speed: Double, center c: NSPoint, width w: CGFloat, height h: CGFloat, front: Bool) {
    guard speed > 0.05 else { return }
    var segs: [(NSBezierPath, CGFloat)] = []
    for (ring, (fy, rx)) in [(0.12, 0.6), (0.4, 0.72), (0.93, 0.56)].enumerated() { // legs, waist, top of the hair: never across his face
        let cy = c.y + h * CGFloat(fy), ex = w * CGFloat(rx), ey = h * 0.07
        let pt = { (p: Double) in NSPoint(x: c.x + ex * CGFloat(cos(p)), y: cy - ey * CGFloat(sin(p))) }
        for streak in 0..<2 {
            let head = -a + Double(ring) * 1.3 + Double(streak) * .pi
            let pieces = 14, len = 2.2 * min(1, speed)
            for i in 0..<pieces { // tail fades out behind the head
                let p0 = head + len * Double(i) / Double(pieces), p1 = head + len * Double(i + 1) / Double(pieces)
                guard (sin((p0 + p1) / 2) > 0) == front else { continue }
                let path = NSBezierPath(); path.move(to: pt(p0)); path.line(to: pt(p1)); path.lineCapStyle = .round
                path.lineWidth = 2
                segs.append((path, CGFloat(min(1, speed * 1.4)) * (1 - CGFloat(i) / CGFloat(pieces))))
            }
        }
    }
    // short dashes further out, off to his sides (never across his face)
    for (k, fy) in [0.24, 0.56, 0.76].enumerated() {
        let cy = c.y + h * CGFloat(fy), ex = w * 0.82, ey = h * 0.06
        let pt = { (p: Double) in NSPoint(x: c.x + ex * CGFloat(cos(p)), y: cy - ey * CGFloat(sin(p))) }
        for d in 0..<5 {
            let p0 = -a * 1.15 + Double(k) * 0.9 + Double(d) * 2 * .pi / 5, p1 = p0 + 0.28 * min(1, speed)
            guard (sin((p0 + p1) / 2) > 0) == front, abs(cos((p0 + p1) / 2)) > 0.55 else { continue }
            let path = NSBezierPath(); path.move(to: pt(p0)); path.line(to: pt(p1)); path.lineCapStyle = .round
            path.lineWidth = 1.6
            segs.append((path, CGFloat(min(1, speed * 1.4)) * 0.9))
        }
    }
    for (path, alpha) in segs { NSColor(white: 0.05, alpha: alpha).setStroke(); path.stroke() }
}

// One moment of the spin, `t` seconds in, centred on midX.
func drawSpinFrame(_ i: Int, at t: Double, midX: CGFloat) {
    let img = lookImages[i], w = spriteH * img.size.width / img.size.height
    let a = spinAngle(t), speed = (spinAngle(t + 0.01) - a) / 0.01 / (spinTurns * 2 * .pi * 2 / spinDur) // 1 = top speed
    let (pose, off) = spinView(a)
    let squash = CGFloat(1 - 0.5 * abs(off) * 2) // narrowest halfway between two views
    let hop: CGFloat = 0, c = NSPoint(x: midX, y: hop) // feet stay on the ground
    drawSpinLines(angle: a, speed: speed, center: c, width: w, height: spriteH, front: false)
    NSGraphicsContext.current?.saveGraphicsState()
    let tr = NSAffineTransform(); tr.translateX(by: midX, yBy: 0); tr.scaleX(by: squash, yBy: 1); tr.translateX(by: -midX, yBy: 0); tr.concat()
    drawMJ(i, frameFor(pose, blink: false), at: NSPoint(x: midX - w / 2, y: hop), height: spriteH)
    NSGraphicsContext.current?.restoreGraphicsState()
    drawSpinLines(angle: a, speed: speed, center: c, width: w, height: spriteH, front: true)
}

final class MikeView: NSView {
    weak var mike: Mike?
    override func draw(_ dirtyRect: NSRect) {
        guard let m = mike else { return }
        let img = lookImages[m.st.look]
        let w = spriteH * img.size.width / img.size.height
        var lift: CGFloat = m.bounce ? 3 : 0
        switch m.pose {
        case .walkA, .walkB: lift += m.moonwalk ? 0 : 1
        case .cheer, .lean, .pointL: lift += m.mode == .show ? 6 : 0
        case .signature: lift += m.mode == .show && m.modeTicks < 8 ? CGFloat(m.modeTicks) : (m.mode == .show && m.modeTicks < 16 ? CGFloat(16 - m.modeTicks) : 0)
        default: break
        }
        var batPerched = false
        if case .side = m.pose, !m.moonwalk, case .bat? = sideDrawing(m.st.look)?.item { batPerched = true } // Legend's drawing has it sitting on his hat
        let batOut = m.mode != .docked && m.mode != .rest && !batPerched
        if batOut { drawBat(midX: bounds.midX, width: w, behind: true) }
        if m.mode == .docked {
            let p = peekImages[m.st.look], k = spriteH / img.size.height, pw = p.size.width * k
            let mirror = (m.dockSide < 0) != peekArtFacesLeftEdge(m.st.look)
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.imageInterpolation = .high
            if mirror { let t = NSAffineTransform(); t.translateX(by: bounds.midX * 2, yBy: 0); t.scaleX(by: -1, yBy: 1); t.concat() }
            p.draw(in: NSRect(x: bounds.midX - pw / 2, y: m.bounce ? 1 : 0, width: pw, height: p.size.height * k))
            NSGraphicsContext.current?.restoreGraphicsState()
        } else if m.spinning, CACurrentMediaTime() - m.spinStart < spinDur {
            drawSpinFrame(m.st.look, at: CACurrentMediaTime() - m.spinStart, midX: bounds.midX)
        } else {
            let gulp = m.mode == .drink && m.modeTicks > 20
            var f = frameFor(m.pose, blink: m.blink, gulp: gulp); f.mirror = m.mirrorArt; f.moon = m.moonwalk
            drawMJ(m.st.look, f, at: NSPoint(x: bounds.midX - w / 2, y: lift), height: spriteH)
        }
        if batOut { drawBat(midX: bounds.midX, width: w, behind: false) }
        drawParticles(m.particles)
        // keep the speech bubble on the visible part of the screen
        let scr = m.screen, wx = window?.frame.minX ?? 0
        if let b = m.bubble {
            drawBubble(b.0, centerX: min(max(bounds.midX, scr.minX - wx + 60), scr.maxX - wx - 60), bottom: spriteH + 4,
                       width: min(bounds.width, scr.maxX - wx), lo: max(2, scr.minX - wx + 2))
        }
    }

    // Click for a "hee-hee!", drag to pick him up.
    var downAt = NSPoint.zero, grabOffset = NSPoint.zero, dragging = false
    override func mouseDown(with e: NSEvent) {
        downAt = NSEvent.mouseLocation
        grabOffset = NSPoint(x: downAt.x - window!.frame.minX, y: downAt.y - window!.frame.minY)
        dragging = false
    }
    override func mouseDragged(with e: NSEvent) {
        let p = NSEvent.mouseLocation
        if !dragging && hypot(p.x - downAt.x, p.y - downAt.y) > 3 { dragging = true; mike?.pickUp() }
        if dragging { mike?.moveHeld(to: NSPoint(x: p.x - grabOffset.x, y: p.y - grabOffset.y)) }
    }
    override func mouseUp(with e: NSEvent) { if dragging { mike?.drop() } else { mike?.poke() } }
    // Right-click opens the same menu as 🎤, for when the menu bar hides it.
    override func menu(for e: NSEvent) -> NSMenu? { (NSApp.delegate as? AppDelegate)?.statusItem.menu }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class Mike {
    let window: NSWindow
    let view = MikeView()
    let studio: Studio
    let synth = Synth()
    var st = Save.load()

    var mode = Mode.falling, modeTicks = 0, modeLength = 0, ticks = 0
    var x: CGFloat = 0, y: CGFloat = 0, vy: CGFloat = 0, facing: CGFloat = 1
    var target: CGFloat = 0, speed: CGFloat = 1.6, moonwalk = false, arrive: (() -> Void)?
    var pose = Pose.stand, showPose = Pose.cheer, blink = false, bounce = false
    var particles: [Particle] = []
    var bubble: (String, Int)?
    var drinkKind = 0, autoJam = false, lastPoke = 0
    var away = false // you've left the computer (5+ minutes without input, or it slept); he greets you when you're back
    var realTitle: String? // the real song playing while he records, if any
    var friend: Friend?, visiting = -1
    var lastVisit = -18000 // tick of the last friend visit; on his own he visits at most every 10 minutes
    var visitDue: Bool { friend == nil && ticks - lastVisit > 18000 }
    var mirrorArt = false // dance pose shown mirrored this time (body only, the hair stays as drawn), for twice the poses
    var spinning = false, spinStart: CFTimeInterval = 0, spinTimer: Timer?
    var zombieDance = false, zombieDir: CGFloat = -1
    var songZombie: Range<Int>? = nil // recording "Thriller": the ticks of his zombie dance
    // in the Thriller video, the zombie dance runs 0:44–1:58
    let thrillerZombie = 44 * 30..<118 * 30
    var lastMoon = 0 // tick of the last moonwalk; on his own he moonwalks at most every 5 minutes
    var status = "chilling in the studio"

    let winW: CGFloat = 320, winH: CGFloat = spriteH + 90
    var screen: NSRect { (NSScreen.main ?? NSScreen.screens[0]).visibleFrame }
    var ground: CGFloat { screen.minY }
    var homeX: CGFloat { studio.homeX }
    var atHome: Bool { abs(x - homeX) < 3 }
    var current: Look { looks[st.look] }

    init() {
        let scr = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        studio = Studio(screen: scr)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winW, height: winH), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        view.frame = NSRect(x: 0, y: 0, width: winW, height: winH); view.mike = self
        window.contentView = view
        studio.records = st.stage
        studio.view.onClick = { [weak self] in self?.record() }
        x = scr.midX; y = scr.maxY - winH // drops in from the top
        place(); window.orderFrontRegardless()
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: helpers

    func place() { window.setFrameOrigin(NSPoint(x: x - winW / 2, y: y)) }
    func setMode(_ m: Mode, for length: Int = 0) {
        if mode == .docked && [.walk, .record, .visit, .rest, .dance, .drink].contains(m) { // step out from the edge first
            x += dockSide < 0 ? 50 : -50; y = floorY; spawn("✦", 2, color: .systemYellow)
        }
        if m != mode && [.show, .dance].contains(m) { mirrorArt = Bool.random() }
        mode = m; modeTicks = 0; modeLength = length; bounce = false; spinning = false; zombieDance = false
    }
    func say(_ s: String, _ ticks: Int = 90) { bubble = (s, ticks) }
    func spawn(_ s: String, _ n: Int, color: NSColor = .systemPink, spread: CGFloat = 14) {
        for i in 0..<n {
            particles.append(Particle(text: s, x: winW / 2 - spread * CGFloat(n) / 2 + CGFloat(i) * spread, y: spriteH - 20,
                                      vx: .random(in: -0.4...0.4), vy: .random(in: 0.6...1.3), life: 55 + i * 8, color: color))
        }
    }
    func show(_ p: Pose, _ length: Int) { showPose = p; setMode(.show, for: length) }
    func walk(to tx: CGFloat, speed sp: CGFloat = 1.6, moon: Bool = false, status s: String, then: (() -> Void)? = nil) {
        let r = ledge.map { $0.rect.insetBy(dx: 25, dy: 0) } ?? screen.insetBy(dx: 40, dy: 0)
        target = max(r.minX, min(r.maxX, tx)); speed = sp; moonwalk = moon; arrive = then; status = s
        sideWalk = walkStyle == 2 || (walkStyle == 0 && (moon || Bool.random()))
        setMode(.walk)
    }
    func goHome(then: (() -> Void)? = nil) {
        if ledge != nil { jumpDown { [weak self] in self?.goHome(then: then) }; return }
        if atHome { then?() ; return }
        walk(to: homeX, status: "heading back to the studio") { [weak self] in
            self?.facing = -1; self?.status = "chilling in the studio"; then?()
        }
    }
    func save() { st.store() }
    func bump(happy h: Double = 0, juice j: Double = 0) {
        st.happy = max(0, min(100, st.happy + h)); st.juice = max(0, min(100, st.juice + j)); save()
    }
    var busy: Bool { mode == .held || mode == .falling }

    // MARK: standing on top of other apps' windows

    struct Ledge { let id: Int; var rect: CGRect; var top: CGFloat { rect.maxY } }
    var ledge: Ledge?, dropThrough = false, afterLanding: (() -> Void)?
    var sideWalk = false
    var walkStyle = UserDefaults.standard.integer(forKey: "DesktopMJ.walkStyle") { // 0 mix, 1 facing forward, 2 sideways
        didSet { UserDefaults.standard.set(walkStyle, forKey: "DesktopMJ.walkStyle") }
    }
    var visitStyle = UserDefaults.standard.integer(forKey: "DesktopMJ.visitStyle") { // same choices, for hanging out with a friend
        didSet { UserDefaults.standard.set(visitStyle, forKey: "DesktopMJ.visitStyle") }
    }
    var visitSide = false // this visit he stands sideways, facing his friend
    var floorY: CGFloat { ledge?.top ?? ground }

    // Other apps' normal windows, front to back, in screen coordinates (origin bottom-left).
    func windows() -> [Ledge] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        let mainH = NSScreen.screens[0].frame.height, me = Int(getpid())
        return info.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0, (w[kCGWindowOwnerPID as String] as? Int) != me,
                  let id = w[kCGWindowNumber as String] as? Int, let bd = w[kCGWindowBounds as String],
                  let b = CGRect(dictionaryRepresentation: bd as! CFDictionary), b.width >= 120, b.height >= 60 else { return nil }
            return Ledge(id: id, rect: CGRect(x: b.minX, y: mainH - b.maxY, width: b.width, height: b.height))
        }
    }
    // Is the spot just on top of window `i` visible, or is a window in front of it there?
    func clear(_ all: [Ledge], _ i: Int, at px: CGFloat) -> Bool {
        let p = CGPoint(x: px, y: all[i].top - 2)
        return !all[..<i].contains { $0.rect.contains(p) } && all[i].top < screen.maxY - 10
    }
    func ledgeCrossed(from y0: CGFloat, to y1: CGFloat) -> Ledge? {
        let all = windows()
        return all.indices.filter { i in
            let l = all[i]
            return l.top <= y0 && l.top >= y1 && x > l.rect.minX + 15 && x < l.rect.maxX - 15 && clear(all, i, at: x)
        }.map { all[$0] }.max { $0.top < $1.top }
    }
    // Ride along when the window moves; fall off when it closes or gets covered.
    func followLedge() {
        guard let l = ledge else { return }
        let all = windows()
        guard let i = all.firstIndex(where: { $0.id == l.id }), clear(all, i, at: x) else {
            ledge = nil; vy = 2; say("Whoa—!", 40); setMode(.falling); return
        }
        x += all[i].rect.minX - l.rect.minX
        ledge = all[i]; y = all[i].top
    }
    func jumpDown(then: (() -> Void)? = nil) {
        ledge = nil; dropThrough = true; afterLanding = then; vy = 5
        say("Hup!", 30); setMode(.falling)
    }

    // MARK: things you can do from the menu

    // MARK: peeking from a screen edge

    var dockSide: CGFloat = 0 // -1 left edge, 1 right edge
    func peekWidth() -> CGFloat { peekImages[st.look].size.width * spriteH / lookImages[st.look].size.height }
    func dock(_ side: CGFloat, atY dy: CGFloat? = nil) {
        guard mode != .held else { return }
        if mode == .record { synth.stop() }
        let r = screen
        dockSide = side; ledge = nil; arrive = nil; vy = 0
        friend?.leave() // no visitors while he's peeking
        y = max(r.minY, min(r.maxY - spriteH - 40, dy ?? r.minY))
        x = side < 0 ? r.minX + peekWidth() / 2 : r.maxX - peekWidth() / 2
        setMode(.docked); status = "peeking from the \(side < 0 ? "left" : "right") edge"
        say(["👀 I'll just watch…", "Peek-a-boo! Hee-hee!", "Don't mind me!"].randomElement()!, 70)
    }
    func undock() {
        guard mode == .docked else { return }
        x += dockSide < 0 ? 50 : -50
        say("Shamone, let's play!", 50); setMode(.falling)
    }

    func poke() {
        guard !busy, ticks - lastPoke > 20 else { return }
        lastPoke = ticks
        if mode == .docked {
            say(["👀 Hee-hee!", "Just watching!", "What are you working on?", "Peek-a-boo!"].randomElement()!, 60)
            spawn("♥", 1); bump(happy: 1); return
        }
        if mode == .record { spawn("♪", 2, color: .systemPurple); return }
        if mode == .rest { wakeUp(["Mm…? I'm up, I'm up!", "Five more minutes…", "Huh? Hee-hee!"].randomElement()!); return }
        say(["Hee-hee!", "Shamone!", "Woo!", "Annie, are you OK?", "Ow!"].randomElement()!, 50)
        bump(happy: 1)
        if mode == .walk || mode == .visit { spawn("♥", 1); return }
        show(.signature, 60); spawn("♥", 2)
    }

    func giveDrink(_ k: Int) {
        guard !busy else { return }
        if mode == .docked { // a sip without leaving his spot
            drinkKind = k; drinkEffect(k); reactToDrink(); setMode(.docked); return
        }
        drinkEffect(k)
        if mode == .record { synth.stop(); studio.onAir = false }
        drinkKind = k; arrive = nil
        setMode(.drink, for: k == 2 ? 30 : 75)
        status = ["sipping orange juice", "drinking a Coca-Cola", "looking at a Pepsi…"][k]
        say(["Orange juice?! ♥", "Ooh, a Coke.", "…is that Pepsi?"][k], 45)
    }

    func openStudio() {
        guard !studio.isOpen else { return }
        studio.window.orderFrontRegardless(); window.orderFrontRegardless()
        if !busy && friend == nil { say("My studio! ♪", 60); goHome { [weak self] in self?.setMode(.idle, for: 200) } }
    }
    func closeStudio() {
        if mode == .record { synth.stop(); setMode(.idle, for: 120); say("Aww, studio's closed.", 60) }
        studio.onAir = false; studio.window.orderOut(nil)
    }

    func record(auto: Bool = false) {
        if !studio.isOpen { if auto { return }; openStudio() }
        guard !busy else { return }
        if mode == .record { return }
        if st.juice < 15 { say("Too thirsty to sing… 🍊?", 90); show(.sad, 60); return }
        if ledge != nil { jumpDown { [weak self] in self?.record(auto: auto) }; return }
        if !atHome { say("To the studio!", 50); goHome { [weak self] in self?.record(auto: auto) }; return }
        autoJam = auto; facing = -1
        let real = auto ? nil : synth.realSong(from: looks[st.look].songs)
        realTitle = real?.title
        let secs = auto ? 16 * 60 / 118 : real?.secs ?? synth.song(stage: st.stage) // jams are silent
        setMode(.record, for: Int(secs * 30))
        songZombie = real?.title == "Thriller" && canZombie && modeLength >= thrillerZombie.upperBound ? thrillerZombie : nil
        status = auto ? "jamming in the studio" : real.map { "recording “\($0.title)”" } ?? "recording a new song"
        say(auto ? "♪ Just jamming…" : real.map { "♪ “\($0.title)”, take one!" } ?? "♪ Take one!", 80)
    }

    func visit(_ k: Int) {
        guard mode != .docked else { say("I'm peeking right now! 👀", 50); return }
        guard !busy, friend == nil else { if friend != nil { say("I'm with \(friends[visiting].name)!", 50) }; return }
        if mode == .record { synth.stop() }
        if ledge != nil { jumpDown { [weak self] in self?.visit(k) }; return }
        let r = screen
        // Friends hang out somewhere away from the studio.
        let right = studio.isOpen ? studio.window.frame.minX - 260 : r.maxX - 120
        let fx = CGFloat.random(in: (r.minX + 120)...max(r.minX + 121, right))
        let f = Friend(kind: k, x: fx, ground: ground)
        friend = f; visiting = k; lastVisit = ticks
        let side: CGFloat = homeX > fx ? 1 : -1
        say("Gonna check on \(friends[k].name)! \(friends[k].emoji)", 70)
        walk(to: fx + side * 85, speed: 2.2, status: "on the way to see \(friends[k].name)") { [weak self] in
            guard let self, self.friend === f else { return }
            self.facing = -side; f.flipped = side < 0 && k != 1
            self.visitSide = self.visitStyle == 2 || (self.visitStyle == 0 && Bool.random())
            self.setMode(.visit, for: 360); self.status = "hanging out with \(friends[k].name)"
        }
    }

    // Two quick turns (front, side, back, other side), then a pose.
    func spin() {
        guard !busy else { return }
        if mode == .record { synth.stop() }
        show(.stand, Int(spinDur * 30) + 50); spinning = true; status = "spinning"
        spinStart = CACurrentMediaTime()
        spinTimer?.invalidate()
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] t in
            guard let self, self.spinning, CACurrentMediaTime() - self.spinStart < spinDur + 0.05 else { t.invalidate(); return }
            self.view.needsDisplay = true
        }
    }
    func moonwalkShow() {
        guard !busy else { return }
        lastMoon = ticks
        if mode == .record { synth.stop() }
        let r = ledge?.rect ?? screen
        let steps: CGFloat = 4, dist = steps * 2 * 9 * 1.3 // 4 steps (glide + feet together each), same pace as always
        let dir: CGFloat = x - dist > r.minX + 40 ? -1 : 1
        facing = -dir
        say("Shamone! 🌙", 60)
        walk(to: x + dir * dist, speed: 1.3, moon: true, status: "moonwalking") { [weak self] in
            guard let self else { return }
            self.say("Hee-hee!", 50); self.spawn("✦", 3, color: .systemYellow)
            self.show(toeImages[self.st.look] != nil ? .toe(mirror: dir > 0) : .point, 60) // up on his toes, turned the way he was facing
        }
    }

    var canZombie: Bool { zombieFrames[st.look] != nil }
    var zombieLength: Int { zombieSides[st.look] != nil ? 300 : 240 }
    // tick `t` of a zombie dance `length` ticks long: arms out, swaying, then a shuffle one way and back, Thriller style.
    // A long one repeats that every 300 ticks, the leftover at the end just swaying.
    func zombieStep(_ t: Int, length: Int) {
        let b = t % 300 // the shuffle takes ticks 80…240 of each round
        if zombieSides[st.look] != nil && t - b + 300 <= length && (80..<240).contains(b) {
            if b == 80 { zombieDir = x - 45 > screen.minX + 40 ? -1 : 1 }
            let dir = b < 160 ? zombieDir : -zombieDir
            x += dir * 0.55; facing = dir > 0 ? 1 : -1
            pose = .zombieSide(left: dir < 0, step: t / 10); bounce = false
        } else {
            pose = .zombie((t / 12) % 2); bounce = (t / 6) % 2 == 0
        }
        if t == 30 { say(["Thriller night! 🧟", "'Cause this is thriller! 🧟", "Grrr-hee-hee!"].randomElement()!, 60) }
    }
    func zombieShuffle() {
        guard !busy, canZombie, mode != .docked else { return }
        if mode == .record { synth.stop() }
        setMode(.dance, for: zombieLength); zombieDance = true; status = "doing the zombie dance"
        say("🧟 Zombie time!", 50)
    }
    func putOn(glasses: Int? = nil, hat: Int? = nil, bat: Bool? = nil, pumpkin: Bool? = nil) {
        if let g = glasses { closet.glasses = g }
        if let h = hat { closet.hat = h }
        if let b = bat { closet.bat = b }
        if let p = pumpkin { closet.pumpkin = p }
        let line: String
        switch (glasses, hat, bat, pumpkin) {
        case (let g?, _, _, _): line = g == 0 ? "Bye, shades." : "Lookin' cool! 😎"
        case (_, let h?, _, _): line = h == 0 ? "Hat off!" : h == 1 ? "Party time! 🎉" : "Abracadabra! ✨"
        case (_, _, let b?, _): line = b ? "A bat buddy! 🦇" : "Bye bye, little bat!"
        default: line = closet.pumpkin ? "Trick or treat! 🎃" : "Candy's all gone…"
        }
        spawn("✨", 3, color: .systemYellow); say(line, 60)
    }

    func wear(_ i: Int) {
        guard isUnlocked(i, stage: st.stage) else { return }
        st.look = i; save(); spawn("✨", 3, color: .systemYellow); say("How do I look? \(looks[i].name)!", 70)
    }

    func reset() {
        synth.stop(); friend?.leave()
        st = Save(); studio.records = 0; save()
        x = screen.midX; y = screen.maxY - winH; setMode(.falling)
        say("Hi! I'm little Mike!", 90)
    }

    func rest(_ length: Int = .random(in: 600...1500)) {
        guard !busy else { return }
        if mode == .record { synth.stop() }
        arrive = nil; setMode(.rest, for: length); status = "taking a nap"
        say(["*yawn*… nap time.", "Just resting my eyes…", "So sleepy… 💤"].randomElement()!, 60)
    }
    // MARK: noticing when you come back
    func checkAway() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if idle > 300 { away = true } else if away && idle < 2 { away = false; welcomeBack() }
    }
    func welcomeBack() {
        guard !busy else { return }
        let line = ["You're back! 👋", "There you are! Hee-hee!", "I missed you! ♥", "Welcome back! Shamone!"].randomElement()!
        bump(happy: 3); spawn("♥", 3)
        if mode == .rest { wakeUp(line); return }
        say(line, 90)
        if mode == .docked || mode == .record || mode == .walk || mode == .visit { return } // just a hello, don't interrupt
        show(.cheer, 80)
    }
    func wakeUp(_ line: String) { setMode(.idle, for: 120); say(line, 60); status = "hanging out" }

    func pickUp() { setMode(.held); say("Whoa!", 40); arrive = nil; synth.stop() }
    func moveHeld(to p: NSPoint) { x = p.x + winW / 2; y = p.y; place() }
    func drop() {
        vy = 0; ledge = nil; dropThrough = false; afterLanding = nil
        let r = screen, half: CGFloat = 45 // let go near a side edge and he peeks from it
        if x - half < r.minX + 25 || x + half > r.maxX - 25 {
            setMode(.idle) // let go of him first, then stick to the edge
            dock(x - half < r.minX + 25 ? -1 : 1, atY: y); return
        }
        setMode(.falling)
    }

    // MARK: growing up

    func finishSong() {
        studio.onAir = false
        st.progress += autoJam ? 34 : 100
        bump(happy: 5, juice: -4)
        guard st.progress >= 100 else {
            say("Nice jam! Almost a song…", 70); show(.stand, 60); return
        }
        st.progress = 0; st.songs += 1; st.totalSongs += 1
        let titles = looks[st.stage].songs
        st.lastSong = realTitle ?? titles[(st.songs - 1) % titles.count]
        say("New song: “\(st.lastSong)”!", 110)
        spawn("♪", 4, color: .systemPurple); show(.cheer, 70)
        if st.songs >= songsPerLook && st.stage < eraCount - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.growUp() }
        }
        save()
    }

    func growUp() {
        st.stage += 1; st.look = st.stage; st.songs = 0; st.progress = 0
        studio.records = st.stage
        spawn("✨", 5, color: .systemYellow, spread: 18); spawn("💿", 1)
        show(.cheer, 90)
        say(st.stage == eraCount - 1 ? "I'm a legend now! Hee-hee!" : "I grew up! Hello, \(current.name) era!", 140)
        save()
    }

    // MARK: life on its own

    func chooseNext() {
        if st.happy < 30 && Int.random(in: 0..<4) == 0 { rest(); return } // a nap cheers him up
        if st.juice < 25 && Int.random(in: 0..<2) == 0 {
            say(["I'm thirsty… orange juice? 🍊", "Some OJ please? 🍊", "Not Pepsi though!"].randomElement()!, 100)
            show(.sad, 120); return
        }
        if ticks - lastMoon > 9000 && Int.random(in: 0..<8) == 0 { moonwalkShow(); return } // now and then, just because
        if ledge == nil && Int.random(in: 0..<12) == 0 { spin(); return }
        if canZombie && Int.random(in: 0..<10) == 0 { zombieShuffle(); return }
        if let l = ledge { // up on a window: hang out, stroll along it, or hop down
            switch Int.random(in: 0..<10) {
            case 0..<3: jumpDown { [weak self] in self?.setMode(.idle, for: 60) }
            case 3..<6: walk(to: .random(in: (l.rect.minX + 30)...(l.rect.maxX - 30)), status: "strolling on a window")
            case 6..<8: setMode(.dance, for: 120); status = "dancing on a window"
            case 8 where Bool.random(): rest()
            default: setMode(.idle, for: .random(in: 200...500)); status = "sitting on top of a window"
            }
            return
        }
        if !studio.isOpen { // studio is put away: roam the screen
            let r = screen
            switch Int.random(in: 0..<100) {
            case 0..<35: walk(to: .random(in: (r.minX + 60)...(r.maxX - 60)), status: "taking a stroll")
            case 35..<50 where visitDue: visit(Int.random(in: 0..<friends.count))
            case 50..<65: setMode(.dance, for: 120); status = "dancing"
            case 65..<77: rest()
            default: setMode(.idle, for: .random(in: 200...600)); status = "hanging out"
            }
            return
        }
        if !atHome {
            if Int.random(in: 0..<10) < 7 { goHome { [weak self] in self?.setMode(.idle, for: 200) } }
            else { setMode(.dance, for: 120); status = "dancing" }
            return
        }
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<28 where st.juice >= 20: record(auto: true)
        case 28..<42:
            let r = screen
            walk(to: .random(in: (r.minX + 60)...(r.maxX - 60)), status: "taking a stroll") { [weak self] in
                guard let self else { return }
                if Bool.random() { self.setMode(.dance, for: 120); self.status = "dancing" } else { self.setMode(.idle, for: 150) }
            }
        case 42..<54 where visitDue: visit(Int.random(in: 0..<friends.count))
        case 54..<62: setMode(.dance, for: 120); status = "dancing in the studio"
        case 62..<72: rest()
        default: setMode(.idle, for: .random(in: 300...800)); status = "chilling in the studio"
        }
    }

    // Hidden: off screen and paused (no songs, no visitors) until the timer runs out or you call him back.
    var hiddenUntil: Date?
    func hide(minutes: Double) {
        if mode == .held { drop() }
        if mode == .record { synth.stop(); studio.onAir = false }
        friend?.leave(); spinning = false
        hiddenUntil = Date().addingTimeInterval(minutes * 60); window.orderOut(nil)
    }
    func unhide() {
        guard hiddenUntil != nil else { return }
        hiddenUntil = nil; window.orderFrontRegardless(); setMode(.idle, for: 120)
        say("I'm back! Hee-hee!", 70); spawn("✨", 3, color: .systemYellow)
    }

    func tick() {
        if let h = hiddenUntil { if Date() >= h { unhide() } else { return } }
        ticks += 1; modeTicks += 1
        studio.tick()
        if ticks % 30 == 0 {
            st.juice = max(0, st.juice - 1.0 / 180)              // ~1 point every 3 minutes
            st.happy = max(0, st.happy - (st.juice < 20 ? 1.0 / 60 : 1.0 / 240))
        }
        if ticks % 900 == 0 { save() }
        if ticks % 30 == 0 { checkAway() }
        blink = ticks % 105 < 4

        switch mode {
        case .idle:
            pose = st.happy < 25 ? .sad : .stand
            if modeLength > 0 && modeTicks >= modeLength { chooseNext() }
            else if modeLength == 0 && modeTicks > 60 { chooseNext() }
        case .walk:
            let d = target - x
            if abs(d) <= speed {
                x = target; let a = arrive; arrive = nil; moonwalk = false
                setMode(.idle, for: 150); a?()
            } else {
                x += d > 0 ? speed : -speed
                facing = (d > 0) != moonwalk ? 1 : -1
                let step = moonwalk ? modeTicks / 9 : ticks / 7 // a moonwalk starts on its glide frame
                pose = sideWalk ? .side(left: (d < 0) != moonwalk, step: step) : (step % 2 == 0 ? .walkA : .walkB)
                if moonwalk && ticks % 10 == 0 {
                    particles.append(Particle(text: "✦", x: winW / 2 + (d > 0 ? -28 : 20), y: 6, vx: d > 0 ? -0.3 : 0.3, vy: 0.4, life: 30, color: .systemYellow))
                }
            }
        case .record:
            studio.onAir = true; studio.thriller = realTitle == "Thriller"
            if let z = songZombie, z.contains(modeTicks) { // Thriller's zombie dance, before the song gets going
                zombieStep(modeTicks - z.lowerBound, length: z.count)
                if modeTicks == z.upperBound - 1 { facing = -1 }
            } else {
                let beat = modeTicks / 12
                pose = [.point, .stand, .signature, .stand][beat % 4]
                bounce = modeTicks % 12 < 6
            }
            if modeTicks % 15 == 0 {
                particles.append(Particle(text: ["♪", "♫", "♬"].randomElement()!, x: winW / 2 + .random(in: -30...20), y: spriteH - 26,
                                          vx: .random(in: -0.4...0.4), vy: 1, life: 50, color: [.systemPurple, .systemPink, .systemTeal].randomElement()!))
            }
            if modeTicks >= modeLength { finishSong() }
        case .dance where zombieDance:
            zombieStep(modeTicks, length: modeLength)
            if modeTicks >= modeLength { setMode(.idle, for: 150) }
        case .dance:
            let phase = modeTicks / 6
            let leftArm = rigs[st.look].armL != nil
            if modeTicks < 50 { pose = [.walkA, .walkB][phase % 2] }                                       // step to the beat
            else if modeTicks < 85 { pose = [.point, leftArm ? .pointL : .lean][phase % 2]; bounce = (modeTicks / 5) % 2 == 0 }
            else { pose = .signature; bounce = false }
            if modeTicks == 86 { say(["Hee-hee!", "Woo!", "Shamone!"].randomElement()!, 45); spawn("✦", 2, color: .systemYellow) }
            if modeTicks >= modeLength { setMode(.idle, for: 150) }
        case .drink:
            pose = .drink(drinkKind)
            if modeTicks % 20 == 10 { particles.append(Particle(text: "glug", x: winW / 2 + 30, y: spriteH - 40, vx: 0.2, vy: 0.5, life: 25, color: .systemGray)) }
            if modeTicks >= modeLength { reactToDrink() }
        case .docked:
            pose = .stand
            bounce = modeTicks % 150 < 8 // a tiny bob now and then
            if modeTicks % 1500 == 0 {
                say(st.juice < 25 ? "Psst… orange juice? 🍊" : ["👀", "Hee-hee!", "Still watching!", "♪ hmm-hmm ♪"].randomElement()!, 70)
            }
        case .rest:
            pose = .rest
            if modeTicks % 40 == 1 {
                particles.append(Particle(text: ["z", "Z", "z"].randomElement()!, x: winW / 2 - 30 + .random(in: -6...6), y: spriteH * 0.55,
                                          vx: -0.2, vy: 0.5, life: 70, color: .systemIndigo))
            }
            if modeTicks % 300 == 0 { bump(happy: 2) }
            if modeTicks >= modeLength { wakeUp(["*stretch* That was nice!", "I feel brand new!", "Shamone, let's go!"].randomElement()!) }
        case .show:
            pose = showPose
            if spinning {
                let t = CACurrentMediaTime() - spinStart
                pose = t < spinDur ? spinView(spinAngle(t)).pose : toeImages[st.look] != nil ? .toe(mirror: false) : .signature
                if modeTicks == Int(spinDur * 30) + 1 { say(["Hee-hee!", "Woo!", "Shamone!"].randomElement()!, 50); spawn("✦", 3, color: .systemYellow) }
            }
            if modeTicks >= modeLength { setMode(.idle, for: 120) }
        case .visit:
            visitTick()
        case .held:
            pose = .held
        case .falling:
            pose = .held
            let before = y
            vy -= 0.8; y += vy
            if !dropThrough, let l = ledgeCrossed(from: before, to: y) {
                ledge = l; y = l.top; vy = 0; show(.stand, 30); spawn("✦", 2, color: .systemYellow)
                say(["Nice view up here!", "Hee-hee! I'm on top!", "Whoa, high up!"].randomElement()!, 60)
            } else if y <= ground {
                y = ground; vy = 0; ledge = nil; dropThrough = false; show(.stand, 30); spawn("✦", 2, color: .systemYellow)
                if let a = afterLanding { afterLanding = nil; a() }
            }
        }
        if ledge != nil && !busy && ticks % 10 == 0 { followLedge() }
        if mode != .record { studio.onAir = false }
        if pose == .sad && ticks % 50 == 0 { spawn("💧", 1, color: .systemBlue) }

        // Stay on screen.
        let r = screen
        if mode != .docked { x = max(r.minX + 30, min(r.maxX - 30, x)) }
        if let l = ledge { x = max(l.rect.minX + 25, min(l.rect.maxX - 25, x)) }
        if mode == .docked { x = dockSide < 0 ? r.minX + peekWidth() / 2 : r.maxX - peekWidth() / 2 }
        else if mode != .held && mode != .falling && y != floorY {
            if y > floorY { setMode(.falling) } else { y = floorY }
        }
        if let b = bubble { bubble = b.1 > 1 ? (b.0, b.1 - 1) : nil }
        for i in particles.indices { particles[i].x += particles[i].vx; particles[i].y += particles[i].vy; particles[i].life -= 1 }
        particles.removeAll { $0.life <= 0 }
        if let f = friend, !f.tick() { friend = nil; visiting = -1 }

        if mode != .held { place() }
        view.needsDisplay = true
    }

    func drinkEffect(_ k: Int) {
        switch k {
        case 0: bump(happy: 20, juice: 45)
        case 1: bump(happy: 3, juice: 25)
        default: bump(happy: -12, juice: 3)
        }
    }

    func reactToDrink() {
        switch drinkKind {
        case 0:
            say("Orange juice! My favourite! ♥", 100); spawn("♥", 4); spawn("🍊", 1)
            synth.jingle([72, 76, 79, 84, 79, 84], bpm: 560)
            show(.cheer, 80)
        case 1:
            say("Mm. It's okay.", 70); show(.stand, 50)
            synth.jingle([67, 72], bpm: 300)
        default:
            say("Pepsi?! Blehh! No way!", 100); spawn("💦", 3, color: .systemBlue)
            synth.jingle([60, 56, 52, 47], bpm: 300)
            show(.sad, 90)
        }
        status = "chilling"
    }

    func visitTick() {
        guard let f = friend, visiting >= 0 else { setMode(.idle, for: 60); return }
        let info = friends[visiting]
        pose = visitSide ? .side(left: facing < 0, step: 0) : .stand
        switch modeTicks {
        case 1:
            say("Hi \(info.name)! ♥", 70); spawn("♥", 3)
        case 70: f.say(info.hello); f.spawn("♥", 3)
        case 140:
            say(info.mjLines.randomElement()!, 80); f.excited = true
        case 140..<220:
            if visitSide { pose = .side(left: facing < 0, step: (modeTicks / 10) % 2) } // a little sideways bop
            else { pose = (modeTicks / 10) % 2 == 0 ? .cheer : .point }
            bounce = (modeTicks / 5) % 2 == 0
            if modeTicks == 160 { f.say(info.lines.randomElement()!, 80) }
        case 220: f.excited = false; bump(happy: 15); spawn("♥", 2)
        case 290: say("See you later, \(info.name)! ♥", 70)
        default: break
        }
        if modeTicks >= modeLength {
            f.leave()
            if studio.isOpen { goHome { [weak self] in self?.setMode(.idle, for: 300) } } else { setMode(.idle, for: 200) }
        }
    }
}

// MARK: - App and menu

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var mike: Mike!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        mike = Mike()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.mike.away = true }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎤"
        let menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
        statusItem.menu = menu
        // Ways to reach him when the 🎤 is hidden behind the notch: ⌃⌥M, or opening DesktopMJ again.
        hotKeyAction = { [weak self] in self?.summon() }
        registerHotKey()
        DistributedNotificationCenter.default().addObserver(forName: summonNote, object: nil, queue: .main) { [weak self] _ in self?.summon() }
    }

    // Brings him back if he's hiding, otherwise opens his menu where the mouse is.
    func summon() {
        if mike.hiddenUntil != nil { mike.unhide(); return }
        guard let menu = statusItem.menu else { return }
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func bar(_ v: Double) -> String {
        let n = Int((v / 100 * 8).rounded())
        return String(repeating: "▰", count: n) + String(repeating: "▱", count: 8 - n)
    }

    func item(_ title: String, _ action: Selector?, tag: Int = 0, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self; i.tag = tag; i.isEnabled = action != nil
        return i
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let m = mike!, s = m.st
        menu.removeAllItems()
        if m.hiddenUntil != nil {
            menu.addItem(item("Little MJ is hiding 🙈", nil))
            menu.addItem(item("👋 Come back now", #selector(unhide), key: "h"))
            menu.addItem(.separator())
            menu.addItem(item("Say goodbye (quit)", #selector(quit), key: "q"))
            return
        }
        menu.addItem(item("Little MJ · \(looks[s.look].name) (\(looks[s.look].year))", nil))
        if s.stage < eraCount - 1 {
            menu.addItem(item("Stage \(s.stage + 1)/\(eraCount) · songs \(s.songs)/\(songsPerLook) to grow up", nil))
        } else {
            menu.addItem(item("Stage \(eraCount)/\(eraCount) · a legend · \(s.totalSongs) songs", nil))
        }
        for (icon, label, v, c) in [("💗", "Happy", s.happy, NSColor.systemPink), ("🍊", "Juice", s.juice, NSColor.systemOrange)] {
            let i = NSMenuItem(); i.view = MeterView(icon, label, v, c); menu.addItem(i)
        }
        menu.addItem(item("Now: \(m.status)" + (s.lastSong.isEmpty ? "" : " · last hit: “\(s.lastSong)”"), nil))
        menu.addItem(.separator())

        let drinks = NSMenu()
        drinks.addItem(item("🍊 Orange juice — his favourite!", #selector(drink(_:)), tag: 0, key: "o"))
        drinks.addItem(item("🥤 Coca-Cola — it's okay", #selector(drink(_:)), tag: 1))
        drinks.addItem(item("🔵 Pepsi — he hates it", #selector(drink(_:)), tag: 2))
        let d = item("Give a drink", #selector(noop)); d.submenu = drinks; menu.addItem(d)

        menu.addItem(item(m.studio.isOpen ? "🏠 Close the studio" : "🏠 Open the studio", #selector(toggleStudio), key: "s"))
        menu.addItem(item("🎙 Record a song in the studio", #selector(record), key: "r"))

        let pals = NSMenu()
        for (i, f) in friends.enumerated() {
            pals.addItem(item("\(f.emoji) \(f.name) the \(f.kind)", m.friend == nil && m.mode != .docked ? #selector(visit(_:)) : nil, tag: i))
        }
        let v = item("Visit a friend", #selector(noop)); v.submenu = pals; menu.addItem(v)

        menu.addItem(item("🌙 Moonwalk!", #selector(moonwalk), key: "m"))
        menu.addItem(item("🌀 Spin!", #selector(spin), key: "s"))
        if m.canZombie { menu.addItem(item("🧟 Zombie dance!", #selector(zombie), key: "z")) }
        if m.mode == .docked {
            menu.addItem(item("🚶 Come out and play", #selector(undock)))
        } else {
            menu.addItem(item("👀 Peek from the left edge", #selector(dockLeft)))
            menu.addItem(item("👀 Peek from the right edge", #selector(dockRight)))
        }
        menu.addItem(item(m.mode == .rest ? "☀️ Wake him up" : "💤 Nap time", #selector(napToggle), key: "n"))
        let hides = NSMenu()
        for (t, mins) in [("1 minute", 1), ("5 minutes", 5), ("15 minutes", 15), ("1 hour", 60)] {
            hides.addItem(item(t, #selector(hide(_:)), tag: mins))
        }
        let hd = item("🙈 Hide for…", #selector(noop)); hd.submenu = hides; menu.addItem(hd)

        let styles = NSMenu()
        for (i, t) in ["Mix it up", "Facing forward", "Sideways"].enumerated() {
            let it = item(t, #selector(setWalkStyle(_:)), tag: i); it.state = m.walkStyle == i ? .on : .off; styles.addItem(it)
        }
        let ws = item("Walking style", #selector(noop)); ws.submenu = styles; menu.addItem(ws)

        let vstyles = NSMenu()
        for (i, t) in ["Mix it up", "Facing forward", "Sideways"].enumerated() {
            let it = item(t, #selector(setVisitStyle(_:)), tag: i); it.state = m.visitStyle == i ? .on : .off; vstyles.addItem(it)
        }
        let vs = item("Visiting style", #selector(noop)); vs.submenu = vstyles; menu.addItem(vs)

        let wardrobe = NSMenu()
        // a recoloured version ("Thriller Era · Blue Uniform") is listed right after the outfit it's based on
        func isVersion(_ i: Int, of j: Int) -> Bool { i != j && looks[i].name.hasPrefix(looks[j].name + " ·") }
        var extras: [Int] = []
        for j in eraCount..<looks.count where !(eraCount..<looks.count).contains(where: { isVersion(j, of: $0) }) {
            extras.append(j); extras += (eraCount..<looks.count).filter { isVersion($0, of: j) } }
        for i in Array(0..<eraCount) + extras {
            let l = looks[i]
            if i == extras.first { wardrobe.addItem(.sectionHeader(title: "Tours & more")) }
            let open = isUnlocked(i, stage: s.stage), tag = i < eraCount ? "\(i + 1). " : ""
            let w = item(open ? "\(tag)\(l.name) (\(l.year))" : "\(tag)🔒 ???", open ? #selector(wear(_:)) : nil, tag: i)
            w.state = i == s.look ? .on : .off
            wardrobe.addItem(w)
        }
        let wd = item("Wardrobe", #selector(noop)); wd.submenu = wardrobe; menu.addItem(wd)

        let cl = NSMenu()
        cl.addItem(.sectionHeader(title: "Glasses"))
        for (i, n) in glassesNames.enumerated() { let it = item(n, #selector(pickGlasses(_:)), tag: i); it.state = closet.glasses == i ? .on : .off; cl.addItem(it) }
        cl.addItem(.sectionHeader(title: "Hats"))
        for (i, n) in hatNames.enumerated() { let it = item(n, #selector(pickHat(_:)), tag: i); it.state = closet.hat == i ? .on : .off; cl.addItem(it) }
        cl.addItem(.sectionHeader(title: "Halloween"))
        let bt = item("🦇 Bat buddy", #selector(toggleBat)); bt.state = closet.bat ? .on : .off; cl.addItem(bt)
        let pk = item("🎃 Pumpkin bucket", #selector(togglePumpkin)); pk.state = closet.pumpkin ? .on : .off; cl.addItem(pk)
        let cm = item("🚪 Closet", #selector(noop)); cm.submenu = cl; menu.addItem(cm)

        menu.addItem(.separator())
        let snd = item("Sound", #selector(toggleSound)); snd.state = m.synth.muted ? .off : .on; menu.addItem(snd)
        menu.addItem(item("Start over as little Mike…", #selector(startOver)))
        menu.addItem(item("Say goodbye (quit)", #selector(quit), key: "q"))
    }

    @objc func noop() {}
    @objc func drink(_ s: NSMenuItem) { mike.giveDrink(s.tag) }
    @objc func record() { mike.record() }
    @objc func toggleStudio() { if mike.studio.isOpen { mike.closeStudio() } else { mike.openStudio() } }
    @objc func visit(_ s: NSMenuItem) { mike.visit(s.tag) }
    @objc func moonwalk() { mike.moonwalkShow() }
    @objc func spin() { mike.spin() }
    @objc func zombie() { mike.zombieShuffle() }
    @objc func pickGlasses(_ s: NSMenuItem) { mike.putOn(glasses: s.tag) }
    @objc func pickHat(_ s: NSMenuItem) { mike.putOn(hat: s.tag) }
    @objc func toggleBat() { mike.putOn(bat: !closet.bat) }
    @objc func togglePumpkin() { mike.putOn(pumpkin: !closet.pumpkin) }
    @objc func dockLeft() { mike.dock(-1) }
    @objc func dockRight() { mike.dock(1) }
    @objc func undock() { mike.undock() }
    @objc func setWalkStyle(_ s: NSMenuItem) { mike.walkStyle = s.tag }
    @objc func setVisitStyle(_ s: NSMenuItem) { mike.visitStyle = s.tag }
    @objc func napToggle() { if mike.mode == .rest { mike.wakeUp("Good morning! Hee-hee!") } else { mike.rest() } }
    @objc func wear(_ s: NSMenuItem) { mike.wear(s.tag) }
    @objc func toggleSound() {
        mike.synth.muted.toggle(); if mike.synth.muted { mike.synth.stop() }
        UserDefaults.standard.set(mike.synth.muted, forKey: "DesktopMJ.muted")
    }
    @objc func startOver() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Start over?"
        a.informativeText = "Mike goes back to being little Mike, and his gold records come off the wall."
        a.addButton(withTitle: "Start over"); a.addButton(withTitle: "Cancel")
        if a.runModal() == .alertFirstButtonReturn { mike.reset() }
    }
    @objc func hide(_ s: NSMenuItem) { mike.hide(minutes: Double(s.tag)) }
    @objc func unhide() { mike.unhide() }
    @objc func quit() { mike.save(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ n: Notification) { mike?.save() }
}

// `--preview out.png` renders every look, pose and friend to an image instead of launching.
if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--preview" {
    _ = NSApplication.shared
    let cell = Int(spriteH * 0.8)
    let w = cell * (looks.count + 1), h = Int(spriteH) + 20 + Int(28 * S) + Studio.h * Int(S) + 10
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    hex(0xf4f1ea).setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    if let c = ProcessInfo.processInfo.environment["MJ_CLOSET"]?.split(separator: ",").compactMap({ Int($0) }), c.count == 4 { // glasses,hat,bat,pumpkin
        closet = Closet(glasses: c[0], hat: c[1], bat: c[2] == 1, pumpkin: c[3] == 1)
    }
    if let look = ProcessInfo.processInfo.environment["MJ_WALK"].flatMap(Int.init) { // a strip of side-walk steps for one look
        let n = 4, cw = Int(spriteH * 0.9), ch = Int(spriteH) + 10
        let rep4 = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cw * n * 2, pixelsHigh: ch, bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep4)
        hex(0xd8e8f0).setFill(); NSRect(x: 0, y: 0, width: cw * n * 2, height: ch).fill()
        let img = lookImages[look - 1], w = spriteH * img.size.width / img.size.height
        let moon = ProcessInfo.processInfo.environment["MJ_MOON"] != nil
        for f in 0..<(n * 2) { var fr = frameFor(.side(left: f >= n, step: f), blink: false); fr.moon = moon; drawMJ(look - 1, fr, at: NSPoint(x: CGFloat(f * cw + cw / 2) - w / 2, y: 4), height: spriteH) }
        try! rep4.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    }
    if let look = ProcessInfo.processInfo.environment["MJ_SPIN"].flatMap(Int.init) { // a strip of spin frames for one look
        let n = 14, cw = Int(spriteH * 1.3), ch = Int(spriteH) + 20
        let rep3 = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cw * n, pixelsHigh: ch, bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep3)
        hex(0x3b2350).setFill(); NSRect(x: 0, y: 0, width: cw * n, height: ch).fill()
        for f in 0..<n { drawSpinFrame(look - 1, at: spinDur * Double(f) / Double(n), midX: CGFloat(f * cw + cw / 2)) }
        try! rep3.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    }
    if ProcessInfo.processInfo.environment["MJ_SIDEEYES"] != nil { // every side drawing, with the eye the finder picked boxed in red
        let sc: CGFloat = 2, cw = 180 * sc, ch = 240 * sc
        let rows = (0..<looks.count).map { i in [sideLeft[i], sideRight[i]] + (moonFrames[i].map { $0.left + $0.right } ?? []) }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cw) * 6, pixelsHigh: Int(ch) * rows.count, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep); NSGraphicsContext.current!.imageInterpolation = .none
        NSColor(white: 0.9, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
        for (ri, row) in rows.enumerated() { for (ci, im) in row.enumerated() {
            let r = NSRect(x: CGFloat(ci) * cw, y: CGFloat(rows.count - 1 - ri) * ch, width: im.size.width * sc, height: im.size.height * sc)
            im.draw(in: r)
            if let (e, l) = sideEye(im, look: ri) {
                (l ? NSColor.red : NSColor.blue).setStroke()
                let b = NSBezierPath(rect: NSRect(x: r.minX + e.minX * sc, y: r.maxY - e.maxY * sc, width: e.width * sc, height: e.height * sc)); b.lineWidth = 2; b.stroke()
            }
        } }
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    }
    if ProcessInfo.processInfo.environment["MJ_HEADS"] != nil { // where the head finder thinks his head and eyes are
        print("glasses", GlassesSize.heads.indices.map { String(format: "%.2f", GlassesSize.unit($0)) })
        for (n, set) in [("look", lookImages), ("pose", poseImages), ("held", heldImages), ("toe", toeImages.compactMap { $0 })] {
            for (i, im) in set.enumerated() { let h = headInfo(im, look: i); print(n, i + 1, Int(h.cx), Int(h.top), Int(h.w), h.eyes.map { "\(Int($0.x)),\(Int($0.y))" } ?? "-") }
        }
        exit(0)
    }
    if ProcessInfo.processInfo.environment["MJ_POSES"] != nil { // a sheet of every look in every pose
        let poses: [(Pose, Bool)] = [(.stand, false), (.stand, true), (.walkA, false), (.walkB, false), (.cheer, false), (.point, false), (.pointL, false), (.lean, false), (.drink(0), false), (.signature, false), (.held, false), (.rest, false), (.back, false), (.toe(mirror: false), false), (.toe(mirror: true), false), (.side(left: true, step: 0), false), (.side(left: false, step: 1), false), (.zombie(0), false), (.zombie(1), false), (.zombieSide(left: true, step: 0), false), (.zombieSide(left: false, step: 1), false)]
        let pw = Int(spriteH * 1.15), ph = Int(spriteH) + 30
        let rep2 = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw * poses.count, pixelsHigh: ph * looks.count, bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep2)
        hex(0x3b2350).setFill(); NSRect(x: 0, y: 0, width: pw * poses.count, height: ph * looks.count).fill()
        for i in 0..<looks.count { for (j, p) in poses.enumerated() {
            var f = frameFor(p.0, blink: p.1); f.mirror = ProcessInfo.processInfo.environment["MJ_MIRROR"] != nil
            drawMJ(i, f, at: NSPoint(x: j * pw + 5, y: (looks.count - 1 - i) * ph + 6), height: spriteH)
        } }
        try! rep2.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    }
    for (i, img) in lookImages.enumerated() {
        img.draw(in: NSRect(x: CGFloat(i * cell), y: CGFloat(h) - spriteH - 10, width: spriteH * img.size.width / img.size.height, height: spriteH))
    }
    for k in 0..<3 { drawGrid(drinkSprites[k], drinkPalette, at: NSPoint(x: looks.count * cell + k * 22, y: h - 60)) }
    for k in 0..<3 { for f in 0..<2 {
        drawGrid(makeFriend(k, frame: f), friendPalette, at: NSPoint(x: (k * 2 + f) * Int(24 * S), y: Studio.h * Int(S) + 10))
    } }
    let sv = StudioView(frame: NSRect(x: 0, y: 0, width: CGFloat(Studio.w) * S, height: CGFloat(Studio.h) * S))
    let ctx = NSGraphicsContext.current!
    ctx.saveGraphicsState()
    let dummy = Studio(screen: NSRect(x: 0, y: 0, width: 2000, height: 1000)); dummy.records = 3; dummy.onAir = true; dummy.t = Int(ProcessInfo.processInfo.environment["MJ_T"] ?? "4") ?? 4
    dummy.thriller = ProcessInfo.processInfo.environment["MJ_THRILLER"] != nil
    dummy.window.orderOut(nil); sv.studio = dummy; sv.draw(sv.bounds)
    ctx.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    exit(0)
}

// ⌃⌥M from anywhere (a Carbon hot key needs no Accessibility permission).
let summonNote = Notification.Name("DesktopMJ.summon")
var hotKeyAction: (() -> Void)?
func registerHotKey() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in hotKeyAction?(); return noErr }, 1, &spec, nil, nil)
    var ref: EventHotKeyRef?
    RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4D4A4D4A, id: 1), GetApplicationEventTarget(), 0, &ref)
}

// Opening DesktopMJ while he's already running calls the running one instead of starting a second Mike.
let me = ProcessInfo.processInfo.processIdentifier
let pgrep = Process(), out = Pipe()
pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep"); pgrep.arguments = ["-x", "DesktopMJ"]; pgrep.standardOutput = out
try? pgrep.run(); pgrep.waitUntilExit()
let others = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).split(separator: "\n").compactMap { Int32($0) }.filter { $0 != me }
if !others.isEmpty {
    DistributedNotificationCenter.default().postNotificationName(summonNote, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon
app.run()
