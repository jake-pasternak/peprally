import Foundation

/// Rich sample content for driving the whole app without a live backend.
/// Gated behind the SAMPLE_FEED launch env var (design / demo only) — every
/// view checks `SampleData.on` and swaps its loader for these fixtures.
/// Strictly monochrome: all avatar shades are equal-channel greys.
///
/// Three rules keep the fixtures honest:
/// 1. One cast (`people`) is the source of truth for names, initials, greys
///    and badges — the feed, threads, notifications and search all read it.
/// 2. `authorId` is the person, never the post id, so blocking someone in the
///    feed or a thread actually removes *everything* they wrote.
/// 3. Every question has its own conversation in `threads` — opening two
///    questions must never show the same replies.
enum SampleData {
    // On whenever you bypass auth for dev (GO_HOME) — there's no real session
    // to load from then anyway — or when explicitly forced with SAMPLE_FEED.
    // The PeprallyDemo target compiles with DEMO defined, which turns them on
    // permanently: that build is the demo, launched by tapping its icon, so it
    // can't rely on env vars the way a simulator run can.
    static let on: Bool = {
        #if DEMO
        return true
        #else
        let env = ProcessInfo.processInfo.environment
        return env["SAMPLE_FEED"] != nil || env["GO_HOME"] != nil
        #endif
    }()

    // avatar greys (no hue)
    private static let g1: UInt = 0xDCDCDC, g2: UInt = 0xD8D8D8, g3: UInt = 0xE0E0E0
    private static let g4: UInt = 0xEAEAEA, g5: UInt = 0xE6E6E6, g6: UInt = 0xE4E4E4
    private static let g7: UInt = 0xE2E2E2, g8: UInt = 0xDEDEDE
    private static let topicGrey: UInt = 0xE8E8E8
    private static let myGrey: UInt = 0xDFDFDF

    // MARK: - Cast

    /// One member of the rally. `id` doubles as the handle (search shows
    /// "@\(id)") and as the block key.
    struct Person {
        let id: String
        let name: String
        let initials: String
        let hex: UInt
        let badge: TrustBadge?
    }

    private static let physician = TrustBadge.verified(credential: "Physician")
    private static let pharmPhD = TrustBadge.verified(credential: "Pharmacology PhD")
    private static let biochem = TrustBadge.verified(credential: "Biochemist")
    private static let endo = TrustBadge.verified(credential: "Endocrinologist")
    private static let sportsMed = TrustBadge.verified(credential: "Sports Medicine")
    private static let pharmacist = TrustBadge.verified(credential: "Pharmacist")
    private static let np = TrustBadge.verified(credential: "Nurse Practitioner")

    static let people: [Person] = [
        // credentialed
        Person(id: "drsarahchen", name: "Dr. Sarah Chen", initials: "SC", hex: g1, badge: physician),
        Person(id: "drmarcuswebb", name: "Dr. Marcus Webb", initials: "MW", hex: g2, badge: pharmPhD),
        Person(id: "dramaraokafor", name: "Dr. Amara Okafor", initials: "AO", hex: g3, badge: biochem),
        Person(id: "drpriyanair", name: "Dr. Priya Nair", initials: "PN", hex: g2, badge: endo),
        Person(id: "drelenaruiz", name: "Dr. Elena Ruiz", initials: "ER", hex: g7, badge: sportsMed),
        Person(id: "drtomhalloran", name: "Dr. Tom Halloran", initials: "TH", hex: g8, badge: pharmacist),
        Person(id: "rn_dayshift", name: "rn_dayshift", initials: "RD", hex: g4, badge: np),
        // moderator — the MOD tag only ever shows on a moderation action
        Person(id: "modjules", name: "modjules", initials: "MJ", hex: g2, badge: .moderator),
        // members
        Person(id: "tendonrehab", name: "tendonrehab", initials: "TR", hex: g5, badge: nil),
        Person(id: "glp1journey", name: "glp1journey", initials: "GJ", hex: g4, badge: nil),
        Person(id: "skeptical_sam", name: "skeptical_sam", initials: "SS", hex: g1, badge: nil),
        Person(id: "peptidenotes", name: "peptidenotes", initials: "PN", hex: g6, badge: nil),
        Person(id: "labratlife", name: "labratlife", initials: "LL", hex: g4, badge: nil),
        Person(id: "nootropicnick", name: "nootropicnick", initials: "NN", hex: g3, badge: nil),
        Person(id: "coachdana", name: "coachdana", initials: "CD", hex: g5, badge: nil),
        Person(id: "peptidepete", name: "peptidepete", initials: "PP", hex: g6, badge: nil),
        Person(id: "mira_lifts", name: "mira_lifts", initials: "ML", hex: g5, badge: nil),
        Person(id: "vialsandvibes", name: "vialsandvibes", initials: "VV", hex: g6, badge: nil),
        Person(id: "dosingdiary", name: "dosingdiary", initials: "DD", hex: g3, badge: nil),
        Person(id: "quietprotocol", name: "quietprotocol", initials: "QP", hex: g7, badge: nil),
    ]

    private static let byId: [String: Person] = Dictionary(
        uniqueKeysWithValues: people.map { ($0.id, $0) })

    private static let me = Person(id: "me", name: "you", initials: "JP", hex: myGrey, badge: nil)

    private static func person(_ id: String) -> Person {
        id == "me" ? me : (byId[id] ?? Person(id: id, name: id, initials: "··", hex: g6, badge: nil))
    }

    // MARK: - Feed

    /// Authored per topic below, then interleaved newest-first so the "All"
    /// tab reads like a real feed rather than four blocks.
    static let feed: [FeedQuestion] = {
        let all = bpcFeed + semaFeed + tbFeed + nadFeed
        return all.enumerated()
            .sorted { (ageMinutes($0.element.time), $0.offset) < (ageMinutes($1.element.time), $1.offset) }
            .map { withTrueAnswerCount($0.element) }
    }()

    /// The row's answer count has to match the conversation you land in when
    /// you tap it — "12 answers" opening onto 7 replies reads as a bug.
    private static func withTrueAnswerCount(_ q: FeedQuestion) -> FeedQuestion {
        guard let lines = threads[q.id] else { return q }
        var copy = q
        copy.answers = lines.count
        return copy
    }

    /// "45m" / "2h" / "3d" / "1w" / "1mo" → minutes, for ordering only.
    private static func ageMinutes(_ time: String) -> Int {
        let digits = time.prefix(while: \.isNumber)
        let n = Int(digits) ?? 0
        switch time.dropFirst(digits.count) {
        case "m":  return n
        case "h":  return n * 60
        case "d":  return n * 60 * 24
        case "w":  return n * 60 * 24 * 7
        case "mo": return n * 60 * 24 * 30
        default:   return n
        }
    }

    private static let bpcFeed: [FeedQuestion] = [
        q("s1", "drsarahchen", "BPC-157", "2h", "Does BPC-157 actually help tendon healing?",
          "The evidence is promising but mostly preclinical — here’s what the studies actually show and where the gaps are.",
          12, 148),
        q("s4", "tendonrehab", "BPC-157", "12h", "6 weeks of BPC-157 + eccentric loading on my golfer’s elbow — progress",
          "Range of motion back to full, pain from 7/10 to 1/10. Protocol details in the thread.",
          41, 210, .image),
        q("s7", "skeptical_sam", "BPC-157", "3h", "Where’s the human data on BPC-157? Everything I find is rodent.",
          "Genuinely asking — if someone has a clinical trial that isn’t a case report, I’d love to read it.",
          53, 188),
        q("s11", "coachdana", "BPC-157", "1d", "Oral vs injectable BPC-157 for gut issues — anyone compared both?",
          "The stable-arginate oral form is marketed for GI. Curious if anyone ran both and noticed a difference.",
          19, 63),
        q("s15", "drsarahchen", "BPC-157", "2d", "PSA: ‘research only’ vendors aren’t sterility-tested — read this before you inject",
          "A quick primer on endotoxin, sterility, and why third-party COAs matter. Not medical advice, just safety.",
          64, 402),
        q("s19", "mira_lifts", "BPC-157", "5d", "Six-month follow-up: what happened after I stopped BPC-157",
          "Everyone posts the 6-week win and disappears. Here’s where my shoulder actually sits half a year later.",
          28, 176, .image),
        q("s24", "dramaraokafor", "BPC-157", "1d", "Meta-analysis of the rodent tendon studies — the effect sizes are all over the place",
          "Pooled 22 animal studies. The direction is consistent, the magnitude isn’t, and the model choice explains most of it.",
          33, 214, .link(title: "Pentadecapeptide BPC-157 in tendon healing: a systematic review of preclinical models",
                         domain: "pubmed.ncbi.nlm.nih.gov")),
        q("s28", "drelenaruiz", "BPC-157", "1d", "PT here: what I actually see in clinic when people come in on peptides",
          "Not a position piece. Just the pattern across ~40 patients who told me they were self-administering.",
          47, 331),
    ]

    private static let semaFeed: [FeedQuestion] = [
        q("s2", "drmarcuswebb", "Semaglutide", "5h", "New RCT: semaglutide cut cardiovascular events 20% in non-diabetics",
          "The first large outcomes trial outside diabetes — worth reading the methods before the headlines run with it.",
          34, 291, .link(title: "Semaglutide and cardiovascular outcomes in patients without diabetes",
                         domain: "nejm.org")),
        q("s3", "glp1journey", "Semaglutide", "9h", "How are you handling week-one semaglutide nausea?",
          "Smaller meals and slower titration made the difference for me. What worked for everyone else?",
          27, 96),
        q("s8", "drpriyanair", "Semaglutide", "6h", "Muscle loss on GLP-1s: how much is real and how do you mitigate it?",
          "Resistance training and protein help, but the lean-mass drop in the trials is real. Let’s talk numbers.",
          31, 240),
        q("s12", "glp1journey", "Semaglutide", "1d", "Plateaued at month 4 on semaglutide — titrate up or add something?",
          "Lost 22 lb then stalled for three weeks at the same dose. Push the dose or is this just the set-point?",
          37, 112),
        q("s17", "drmarcuswebb", "Semaglutide", "3d", "Compounded vs brand semaglutide — is the peptide actually the same?",
          "Setting price aside: are there real quality/identity concerns with compounded sources right now?",
          45, 176),
        q("s20", "drtomhalloran", "Semaglutide", "7h", "Pharmacist here — the three dosing errors I see every single week",
          "None of them are exotic. Wrong syringe units, double-dosing after a missed week, and storing pens in the door.",
          39, 268),
        q("s23", "rn_dayshift", "Semaglutide", "11h", "Do you hold the dose through a bad flu week?",
          "Dehydration plus delayed gastric emptying feels like a bad combination. What’s everyone actually doing?",
          24, 87),
        q("s27", "glp1journey", "Semaglutide", "4d", "Travelling with pens — what actually works for a 20-hour flight?",
          "Cooler bag, hotel minibar, TSA questions. Tell me your real setup, not the pamphlet version.",
          18, 71),
    ]

    private static let tbFeed: [FeedQuestion] = [
        q("s6", "peptidenotes", "TB-500", "18h", "TB-500 stacking with BPC-157 — redundant or synergistic?",
          "Mechanistically they hit different pathways, but is there any human data on the combo?",
          22, 74),
        q("s9", "labratlife", "TB-500", "8h", "Reconstitution + storage: how long is TB-500 stable in the fridge?",
          "Getting conflicting answers — some say 8 weeks reconstituted, some say 4. What are you actually seeing?",
          14, 41),
        q("s14", "peptidepete", "TB-500", "2d", "TB-500 for a partial rotator cuff tear — realistic expectations?",
          "Grade 1 partial, no surgery recommended. Is this a reasonable adjunct to PT or wishful thinking?",
          12, 38),
        q("s18", "tendonrehab", "TB-500", "4d", "Combining TB-500 with physical therapy — timing question",
          "Do you dose before or after PT sessions, and does it actually change how the loading feels?",
          11, 29),
        q("s22", "labratlife", "TB-500", "4d", "Full bloodwork before and after 8 weeks of TB-500 — nothing moved",
          "CBC, CMP, lipids, hs-CRP. Posting the panel because null results never get posted.",
          26, 194, .image),
        q("s26", "vialsandvibes", "TB-500", "3d", "Cost per cycle, honestly — post your real numbers",
          "Vial price, bac water, syringes, the lot. I want to know if I’m being quietly fleeced.",
          31, 118),
        q("s30", "mira_lifts", "TB-500", "6d", "Vial arrived warm after three days in transit. Bin it?",
          "Lyophilised, still under vacuum, but the pack was room temperature when it landed. Worth the risk or not?",
          17, 52),
    ]

    private static let nadFeed: [FeedQuestion] = [
        q("s5", "dramaraokafor", "NAD+", "16h", "Is sublingual NAD+ absorption actually meaningful?",
          "Bioavailability data suggests most of it never makes it past first-pass metabolism. Convince me otherwise.",
          18, 133),
        q("s10", "nootropicnick", "NAD+", "14h", "NAD+ IV vs injections vs precursors — what’s worth the money?",
          "The IV clinics are expensive. Are injections or NMN/NR precursors getting you most of the way there?",
          26, 88),
        q("s13", "dramaraokafor", "NAD+", "2d", "Does NAD+ actually cross into cells, or get degraded to precursors first?",
          "The transporter question matters for whether injecting NAD+ itself makes sense vs just giving NMN.",
          21, 95),
        q("s16", "labratlife", "NAD+", "3d", "Flushing on NAD+ injections — normal, or am I pushing it too fast?",
          "Intense flush and a bit of nausea for ~10 min. Slower push fixed it — but is the flush itself a problem?",
          16, 44),
        q("s21", "dosingdiary", "NAD+", "20h", "Sleep got worse on NAD+ — anyone else moved to morning dosing?",
          "Wired at 1am for the first two weeks. Shifting the dose to 7am fixed it entirely. Coincidence?",
          23, 81),
        q("s25", "skeptical_sam", "NAD+", "2d", "How much of the NAD+ ‘energy’ feeling is just the flush?",
          "A strong somatic sensation is the perfect setup for placebo. Has anyone here run it blinded on themselves?",
          29, 143),
        q("s29", "rn_dayshift", "NAD+", "5d", "NAD+ and shift work — timing around a rotating roster",
          "Nights one week, days the next. There’s no ‘morning’ to dose in. How do you anchor it?",
          15, 57),
    ]

    // MARK: - Threads
    //
    // One conversation per question. Split into per-topic groups so the Swift
    // type-checker doesn't choke on a single 30-entry literal.

    /// One line of a conversation, before it becomes a `ReplyItem`.
    private struct Line {
        let who: String
        let time: String
        let text: String
        let vouches: Int
    }

    private static func l(_ who: String, _ time: String, _ text: String, _ vouches: Int) -> Line {
        Line(who: who, time: time, text: text, vouches: vouches)
    }

    static func replies(for questionId: String) -> [ReplyItem] {
        build(questionId, threads[questionId] ?? fallbackThread)
    }

    private static func build(_ qid: String, _ lines: [Line]) -> [ReplyItem] {
        lines.enumerated().map { i, line in
            let p = person(line.who)
            return ReplyItem(id: "\(qid)-r\(i + 1)", authorId: p.id, author: p.name,
                             initials: p.initials, avatarHex: p.hex, badge: p.badge,
                             time: line.time, text: line.text,
                             isMine: p.id == "me", vouches: line.vouches)
        }
    }

    private static let threads: [String: [Line]] = {
        var d: [String: [Line]] = [:]
        for group in [bpcThreads, semaThreads, tbThreads, nadThreads, myThreads] {
            for (id, lines) in group { d[id] = lines }
        }
        return d
    }()

    /// Shown for anything without a scripted conversation — e.g. a question
    /// you just composed in the demo.
    private static let fallbackThread: [Line] = [
        l("drsarahchen", "1h", "Good question, and an under-discussed one. The honest answer is that the mechanism is plausible and the animal data is consistent, but there’s no controlled human trial to point you at yet.", 22),
        l("skeptical_sam", "2h", "Adding the usual caveat before this thread fills with anecdotes: without a control arm, six weeks of anything looks like it worked.", 14),
        l("peptidenotes", "4h", "Following. If anyone has a source that isn’t a vendor blog post, drop it here — I’ll read anything with a methods section.", 8),
        l("coachdana", "7h", "The boring variables — sleep, protein, load management — move the needle more than most people want to hear. Worth ruling those out first.", 11),
    ]

    // MARK: BPC-157 threads

    private static let bpcThreads: [(String, [Line])] = [
        ("s1", [
            l("drsarahchen", "2h", "To pre-empt the obvious question: the strongest tendon data is Chang et al. in rats, where the effect on load-to-failure was large and reproducible. Nothing equivalent exists in humans. I’d treat protocols as informed experimentation, not established medicine.", 41),
            l("tendonrehab", "1h", "n=1, but it genuinely changed my recovery timeline — local injection near the insertion, paired with eccentrics. The loading is doing work too; hard to isolate.", 21),
            l("skeptical_sam", "1h", "Careful with the anecdotes. Tendons improve over 6 weeks with loading alone. Without a control arm you can’t attribute it to the peptide.", 18),
            l("me", "1d", "In my experience local injection near the tendon helped more than systemic — but I was also loading hard, so grain of salt.", 6),
            l("drmarcuswebb", "50m", "Worth separating pharmacokinetics from outcomes. Even if it’s systemically active, ‘active’ ≠ ‘clinically better than PT.’ That’s the study nobody has run.", 27),
            l("drelenaruiz", "35m", "From the clinic side: the patients who do well are almost always the ones who also fixed their loading programme. I have never seen it rescue a tendon that was still being aggravated daily.", 33),
            l("peptidenotes", "20m", "Doses people report: 250–500mcg near the site, once daily, 4–6 weeks. Not a recommendation — just what shows up repeatedly in the write-ups.", 9),
        ]),
        ("s4", [
            l("tendonrehab", "11h", "Protocol as promised: 250mcg subq near the medial epicondyle each morning, 6 weeks. Eccentric wrist curls 3×15 daily from week 2, load added weekly. No NSAIDs the whole time.", 34),
            l("coachdana", "9h", "The eccentrics from week 2 are doing a lot of the work here, for what it’s worth. That’s a textbook tendinopathy programme on its own.", 22),
            l("tendonrehab", "8h", "Completely fair, and I said as much in the post — I’m not claiming a clean attribution. What I can say is I ran the same eccentric programme in February and stalled at 4/10.", 19),
            l("drelenaruiz", "6h", "That February comparison is the most interesting part of this. Different starting load tolerance though — worth noting you were also nine months further into deconditioning then.", 15),
            l("mira_lifts", "4h", "How’s the pain sitting now that you’ve stopped? That’s the bit nobody posts.", 12),
            l("tendonrehab", "3h", "Three weeks off and holding at 1/10. I’ll post again at the six-month mark either way.", 17),
        ]),
        ("s7", [
            l("drmarcuswebb", "2h", "You’re not missing anything — there isn’t one. There are two registered trials on ClinicalTrials.gov for the oral form in IBD; both are small and neither has posted results. Everything else is preclinical or case reports.", 48),
            l("drsarahchen", "2h", "Correct. And the reason isn’t conspiracy, it’s economics: it’s an unpatentable 15-amino-acid sequence. Nobody is funding a phase III on that.", 39),
            l("skeptical_sam", "1h", "That’s the answer I expected, and I appreciate the straight version of it. It’s the ‘studies show’ phrasing in the marketing that bothers me — the studies are rats.", 26),
            l("dramaraokafor", "1h", "The preclinical body is genuinely large, and consistent in direction. That’s worth something. It just isn’t worth what a vendor page implies it’s worth.", 31),
            l("quietprotocol", "45m", "Is there anything in the veterinary literature? Genuine question — horses get tendon injuries and there’s money in it.", 7),
            l("dramaraokafor", "30m", "A little, and it’s mostly the same picture: small n, short follow-up, no blinding.", 11),
        ]),
        ("s11", [
            l("coachdana", "22h", "To be clear about what I’m asking: I have clients on both, and the oral group reports GI improvement more often. But they’re also the ones who came in *with* GI complaints, so I don’t trust my own sample.", 16),
            l("drsarahchen", "20h", "That’s selection, yes. The mechanistic argument for oral in GI is at least coherent though — you’re trying to act on the gut lining locally, which is the one place the absorption problem doesn’t matter.", 28),
            l("quietprotocol", "16h", "Ran oral for eight weeks for reflux. Nothing. Ran it again after fixing my meal timing and it ‘worked’. I think my meal timing worked.", 21),
            l("peptidenotes", "12h", "The arginate salt is the whole pitch for oral — it’s supposed to survive gastric acid. Whether it does at the doses sold is a separate question and I’ve never seen it tested independently.", 14),
            l("drtomhalloran", "9h", "It’s also the form with the least consistent labelling of anything in this category. Two products, same claim, no way to tell what’s in either.", 19),
        ]),
        ("s15", [
            l("drsarahchen", "2d", "Three things to check before anything goes in your body: a third-party COA with an identity assay, an endotoxin figure in EU/mg, and a sterility statement. If a vendor can’t produce all three, that’s your answer.", 87),
            l("drtomhalloran", "2d", "Adding the pharmacy version: ‘research use only’ is a legal carve-out, not a quality tier. It exists precisely so the product doesn’t have to meet the standards you’re assuming it meets.", 64),
            l("labratlife", "2d", "I’ve had two vendors send a COA that was a scanned PDF for a different lot number. Check the lot matches the vial in your hand.", 43),
            l("modjules", "1d", "Pinning this. Reminder that vendor names and sourcing links stay out of the thread — safety discussion is welcome, a marketplace is not.", 52),
            l("mira_lifts", "1d", "The endotoxin point deserves more attention. Sterile and low-endotoxin aren’t the same thing and plenty of ‘sterile filtered’ claims only cover the first one.", 29),
            l("skeptical_sam", "22h", "Genuinely the most useful post on here. No protocol, no anecdote, just the checks.", 33),
        ]),
        ("s19", [
            l("mira_lifts", "5d", "Short version: the shoulder held. Not perfect — about 8/10 of where it was pre-injury — but no regression in six months and I stopped everything at week seven.", 41),
            l("drelenaruiz", "4d", "This is the follow-up that actually informs anything. Holding at six months post-cessation is more interesting than the six-week number ever was.", 36),
            l("tendonrehab", "4d", "Did you keep loading it after you stopped?", 12),
            l("mira_lifts", "4d", "Yes — twice weekly, lighter. I think that’s inseparable from the result, honestly.", 18),
            l("skeptical_sam", "3d", "So the honest read is: you rehabbed a shoulder over six months and also took a peptide for seven weeks of it.", 24),
            l("mira_lifts", "3d", "That is a completely fair read and I’m not going to argue with it. I posted the timeline so people could draw exactly that conclusion if they want to.", 39),
            l("coachdana", "2d", "More of this please. The ones who get better vanish and the ones who don’t never post at all.", 27),
        ]),
        ("s24", [
            l("dramaraokafor", "1d", "Headline: pooled effect on load-to-failure is real but the confidence interval is enormous, and injury model explains most of the heterogeneity. Transection studies look great, overuse models much less so.", 52),
            l("drmarcuswebb", "22h", "Which matters a lot, because almost nobody reading this has a transected tendon. The overuse subgroup is the one that maps to human tendinopathy and it’s the weakest.", 44),
            l("dramaraokafor", "20h", "Exactly the point I wanted people to take from it. The strongest data is from the least relevant model.", 38),
            l("skeptical_sam", "18h", "Did you find publication bias?", 15),
            l("dramaraokafor", "16h", "Funnel plot is asymmetric, yes. With 22 studies I wouldn’t over-read it, but it leans the way you’d expect.", 29),
            l("drsarahchen", "12h", "Worth adding to the pinned safety post as a reference. This is the honest state of the evidence in one place.", 22),
        ]),
        ("s28", [
            l("drelenaruiz", "1d", "The pattern, since people will ask: about a third arrive having stopped their loading programme because the peptide was ‘handling it’. That group does worst, by a distance.", 71),
            l("coachdana", "22h", "This matches what I see as a coach almost exactly. The peptide becomes a reason to skip the boring part.", 43),
            l("tendonrehab", "20h", "Guilty of this in 2024. Felt better, trained through it, set myself back four months.", 38),
            l("drsarahchen", "18h", "It’s the most under-appreciated harm in this space — not the compound, the behaviour it licenses.", 56),
            l("quietprotocol", "14h", "What does the group that does *well* have in common?", 19),
            l("drelenaruiz", "12h", "They treat it as an adjunct and change nothing else about their rehab. Every single time.", 47),
            l("me", "9h", "This reframed how I think about the whole category, honestly. Saving it.", 8),
        ]),
    ]

    // MARK: Semaglutide threads

    private static let semaThreads: [(String, [Line])] = [
        ("s2", [
            l("drmarcuswebb", "5h", "Before the headlines: it’s a composite endpoint, the absolute risk reduction is ~1.5 percentage points, and the population was overweight with established CVD. All three matter for who this applies to.", 62),
            l("drpriyanair", "4h", "And the weight loss confounds the mechanism question badly. We can’t yet say whether this is a drug effect or a weight effect, and the trial wasn’t designed to separate them.", 48),
            l("drsarahchen", "3h", "The pre-specified subgroup by baseline BMI is the interesting bit — the benefit doesn’t track weight loss as cleanly as you’d expect if it were purely a weight effect.", 41),
            l("drmarcuswebb", "3h", "Agreed, that’s the strongest hint of a direct effect in the paper. Still a subgroup, still hypothesis-generating.", 35),
            l("skeptical_sam", "2h", "Genuine thanks for posting the actual numbers. Every version of this I saw yesterday said ‘20% reduction’ and stopped there.", 29),
            l("glp1journey", "1h", "As someone taking it: this is the thread that made me understand what the 20% actually means. Relative risk is doing a lot of lifting in the press release.", 24),
        ]),
        ("s3", [
            l("glp1journey", "8h", "What worked for me, since people asked: last meal by 7pm, dose Saturday morning so the worst day lands on a Sunday, and nothing greasy for 48 hours after.", 31),
            l("rn_dayshift", "7h", "The dose-timing trick is underrated. Half our clinic patients dose Friday night for exactly this reason.", 26),
            l("drpriyanair", "6h", "The other half of it is titration discipline. Most week-one nausea I see is someone who escalated on schedule when they should have held at the lower dose another fortnight.", 38),
            l("me", "2d", "Splitting the dose timing and eating my last meal earlier basically fixed it for me by day 4.", 7),
            l("dosingdiary", "4h", "Ginger did nothing for me, cold water and small volumes did. Everyone’s answer here seems to be different.", 14),
            l("drtomhalloran", "3h", "Worth flagging: persistent vomiting past week two isn’t ‘week-one nausea’ and shouldn’t be managed with tricks from a forum. That’s a call-your-prescriber situation.", 33),
        ]),
        ("s8", [
            l("drpriyanair", "6h", "The trial numbers, since they get quoted loosely: roughly 25–40% of total weight lost was lean mass in the STEP DEXA substudies. That’s not wildly out of line with any rapid weight loss, but it’s not nothing either.", 57),
            l("coachdana", "5h", "And the ‘not out of line with other weight loss’ framing is the part people skip. Compare it to a crash diet, not to standing still.", 34),
            l("drpriyanair", "4h", "Right. The relevant comparison is matched-rate weight loss without the drug, and by that standard it looks fairly ordinary.", 29),
            l("mira_lifts", "3h", "Anecdotally: two lifting sessions a week and 1.6g/kg protein and my DEXA barely moved on lean mass over five months. It’s doable, it’s just work.", 41),
            l("skeptical_sam", "2h", "Do we have any data on whether the lean mass comes back after cessation?", 18),
            l("drpriyanair", "2h", "Very little, and that’s the honest gap. Follow-up in most of these trials ends before the question gets interesting.", 26),
            l("glp1journey", "1h", "Protein is the whole game. I was eating maybe 60g a day for the first two months because I simply wasn’t hungry.", 22),
        ]),
        ("s12", [
            l("drpriyanair", "1d", "Three weeks isn’t a plateau, it’s a fluctuation. Most of the trial curves flatten and then resume — I’d hold the dose and give it another month before changing anything.", 44),
            l("glp1journey", "1d", "That’s reassuring and also not what I wanted to hear. Fine.", 31),
            l("dosingdiary", "22h", "Same thing at month four, same dose, and it resumed at week six without me touching anything.", 27),
            l("coachdana", "20h", "Also worth weighing yourself the same way for a fortnight before calling anything. Most ‘plateaus’ I get texted about are water.", 23),
            l("me", "18h", "Went through this at almost exactly the same point. Held the dose, it moved again three weeks later.", 9),
            l("drtomhalloran", "14h", "The thing not to do is escalate early because of impatience — that’s where the side-effect burden comes from and it doesn’t buy you a faster curve.", 36),
        ]),
        ("s17", [
            l("drmarcuswebb", "3d", "The identity question is answerable: ask for the COA with the mass spec. The one that isn’t answerable from the outside is whether the salt form is the same as the approved product, and several compounded sources use a different one.", 58),
            l("drtomhalloran", "3d", "This is the crux, and it’s not a pedantic distinction — the acetate salt hasn’t been through the same testing. ‘Same peptide’ and ‘same product’ aren’t interchangeable claims.", 61),
            l("glp1journey", "2d", "So for someone who can’t afford brand — is the answer ‘don’t’, or ‘do, with these checks’?", 34),
            l("drtomhalloran", "2d", "It’s ‘understand what you’re accepting’. A 503B outsourcing facility is a very different proposition to a website. I won’t give you a yes or no on the internet.", 47),
            l("drsarahchen", "2d", "The COA-and-lot-number checks in the safety thread apply here more than anywhere else in this app.", 39),
            l("vialsandvibes", "1d", "Anyone who tells you the price difference is pure margin has never read a cGMP inspection report.", 25),
        ]),
        ("s20", [
            l("drtomhalloran", "7h", "The syringe one is the dangerous one. Units on an insulin syringe are not milligrams and I have taken that phone call more than once.", 66),
            l("rn_dayshift", "6h", "Seconding hard. If you’re drawing from a vial rather than using a pen, write the conversion down and tape it to the box.", 43),
            l("drpriyanair", "5h", "And the missed-week one: you don’t double up. You take the next scheduled dose. Doubling is how people end up in urgent care with intractable vomiting.", 51),
            l("glp1journey", "4h", "The fridge door thing surprised me. Is the temperature swing really enough to matter?", 19),
            l("drtomhalloran", "4h", "The door is the warmest and most variable part of the fridge. It won’t destroy a pen overnight, but across weeks it eats into potency and stability margins.", 37),
            l("dosingdiary", "2h", "Bought a $12 fridge thermometer after a thread like this last year. Door was sitting at 11°C.", 28),
        ]),
        ("s23", [
            l("rn_dayshift", "10h", "Asking because I had a patient this week who kept dosing through a vomiting illness and ended up on fluids for AKI. Small n, but it stuck with me.", 39),
            l("drpriyanair", "9h", "Dehydration plus reduced intake plus delayed emptying is a genuinely bad combination. Holding a week is almost always the right call and costs you very little.", 52),
            l("drsarahchen", "8h", "Agreed. Nobody loses their progress over one skipped dose. Kidneys are less forgiving.", 46),
            l("glp1journey", "6h", "Good to have this said plainly. I white-knuckled through norovirus in March because I thought skipping would reset my tolerance.", 31),
            l("drpriyanair", "5h", "It doesn’t reset tolerance after one week. After several, you re-titrate — which is a mild inconvenience, not a setback.", 34),
            l("drtomhalloran", "3h", "Restart at the previous dose, not the next one up. That’s the step people skip.", 29),
        ]),
        ("s27", [
            l("glp1journey", "4d", "My setup: Frio wick bag in the carry-on, never checked, pens in original packaging with the pharmacy label on. Twenty hours, no problem.", 24),
            l("rn_dayshift", "3d", "Label on the box is the important part. It turns a bag full of needles into an obvious medical item.", 31),
            l("dosingdiary", "3d", "Ask for the fridge at the hotel front desk rather than using the minibar — half of those are cooled to about 14°C.", 22),
            l("drtomhalloran", "2d", "Also carry the prescription, and know that most pens tolerate a few days at room temperature. Check your specific product’s in-use window rather than assuming.", 27),
            l("quietprotocol", "1d", "TSA has never once asked me about it in four trips. The anxiety is worse than the reality.", 16),
        ]),
    ]

    // MARK: TB-500 threads

    private static let tbThreads: [(String, [Line])] = [
        ("s6", [
            l("peptidenotes", "17h", "To be specific: BPC is mostly angiogenesis and growth-factor signalling, TB-500 is actin sequestration and cell migration. On paper that’s complementary, not redundant.", 28),
            l("dramaraokafor", "15h", "On paper, yes. In practice nobody has run the combination against either arm alone in anything, in any species, that I can find.", 34),
            l("me", "4d", "Ran both for 5 weeks. Can’t give you a controlled answer, but recovery felt faster than either alone.", 6),
            l("skeptical_sam", "12h", "So the honest answer to the thread title is ‘unknown’, and everything below that is mechanism-story plus vibes.", 26),
            l("peptidenotes", "10h", "That’s fair, and it’s roughly why I asked rather than asserted.", 15),
            l("drelenaruiz", "8h", "The clinical reality is that stacking also doubles your variables. If it goes wrong you won’t know which one did it.", 31),
        ]),
        ("s9", [
            l("labratlife", "7h", "For reference, my own testing: reconstituted with bacteriostatic water, kept at 4°C, still assaying fine at week 6. I stopped there because I ran out, not because it degraded.", 22),
            l("drtomhalloran", "6h", "Bacteriostatic vs sterile water is the variable people leave out of these threads. The benzyl alcohol is what buys you the multi-week window.", 34),
            l("labratlife", "6h", "Yes — should have led with that. Sterile water and you’re looking at days, not weeks.", 19),
            l("vialsandvibes", "4h", "The 4-week number floating around seems to come from one vendor FAQ that everyone copied.", 17),
            l("dramaraokafor", "3h", "Which is the general problem with storage guidance in this space: it’s citation-free folklore, repeated until it sounds official.", 26),
            l("mira_lifts", "2h", "Freeze the lyophilised vial, reconstitute what you’ll use in a month. That’s the whole answer for most people.", 21),
        ]),
        ("s14", [
            l("drelenaruiz", "2d", "Realistic expectations for a grade 1 partial: the natural history is decent with good rehab, which also means anything you add will look like it worked. Set your expectations against that baseline, not against nothing.", 37),
            l("peptidepete", "2d", "That’s a helpful framing and mildly deflating, which probably means it’s right.", 21),
            l("tendonrehab", "1d", "Cuffs are slow. Mine took nine months and the last three were the ones that mattered.", 18),
            l("drsarahchen", "1d", "The thing I’d actually push on: has anyone checked why the tear happened? Scapular mechanics don’t fix themselves and a peptide certainly won’t fix them.", 32),
            l("peptidepete", "22h", "Nobody has looked at that, no. Booking it.", 24),
            l("coachdana", "18h", "That single reply is worth more than the rest of the thread combined.", 29),
        ]),
        ("s18", [
            l("tendonrehab", "4d", "My read after doing both ways: timing relative to the session doesn’t obviously matter, timing relative to *consistency* does. Same time each day beat any clever scheduling.", 19),
            l("drelenaruiz", "3d", "That matches the pharmacology — you’re not chasing an acute window here. Adherence is the variable with a real effect size.", 26),
            l("peptidenotes", "3d", "People borrow the pre-workout mental model from supplements and it doesn’t transfer.", 14),
            l("quietprotocol", "2d", "Does it change how the loading feels though? That was the actual question.", 11),
            l("tendonrehab", "2d", "Honestly, no. The sessions felt the same. What changed was how I felt the next morning.", 17),
        ]),
        ("s22", [
            l("labratlife", "4d", "Posting this because null results never get posted. Eight weeks, nothing outside reference range moved in either direction, including hs-CRP which I half-expected to shift.", 48),
            l("dramaraokafor", "3d", "This is a genuinely useful post. Also worth saying: a normal panel is reassuring for safety, but it was never going to be sensitive to the thing you were hoping for.", 41),
            l("drsarahchen", "3d", "Right — no change on a CMP is the expected result, not a disappointing one. It means nothing broke.", 36),
            l("skeptical_sam", "2d", "More null posts, fewer transformation posts. This is the standard.", 33),
            l("vialsandvibes", "2d", "What did it cost you to run the panel twice?", 12),
            l("labratlife", "1d", "About $180 total through a direct-order lab. Cheap relative to the vials, frankly.", 19),
        ]),
        ("s26", [
            l("vialsandvibes", "3d", "I’ll start. 5mg vial $58, bac water $4, 100 insulin syringes $16, alcohol swabs $5. Call it $83 for roughly five weeks at my dose.", 27),
            l("labratlife", "3d", "Similar, plus $180 twice a year for bloodwork, which I’d argue belongs in the total.", 31),
            l("mira_lifts", "2d", "Adding it up honestly the first time was what made me stop the stack and keep one thing.", 24),
            l("coachdana", "2d", "This is the most useful thread on here for anyone deciding whether to start. The cost is never in the vial price alone.", 22),
            l("drtomhalloran", "1d", "And if the cheap option is cheap because it skipped testing, you’re not comparing like with like.", 29),
        ]),
        ("s30", [
            l("drtomhalloran", "6d", "Lyophilised powder under vacuum is considerably more robust than people assume — room temperature in transit for a few days is generally within tolerance. The vacuum still holding is the reassuring part.", 33),
            l("labratlife", "5d", "Agreed. I’d be more worried if the stopper had lifted or the cake looked collapsed or discoloured. Does it still look like a solid puck?", 21),
            l("mira_lifts", "5d", "Solid, white, no shrinkage. Vacuum pulled the water in fine when I tested one.", 15),
            l("drtomhalloran", "5d", "Then I wouldn’t bin it on transit temperature alone. Ask the vendor for the stability data — how they answer tells you as much as the answer does.", 28),
            l("vialsandvibes", "4d", "Every vendor I’ve asked that question has either sent a real document or gone quiet. Very clarifying.", 26),
        ]),
    ]

    // MARK: NAD+ threads

    private static let nadThreads: [(String, [Line])] = [
        ("s5", [
            l("dramaraokafor", "15h", "The specific problem: NAD+ is a large, charged dinucleotide. Sublingual mucosa handles small lipophilic molecules well and things like this very poorly. I’m open to being wrong but I want data, not marketing.", 39),
            l("nootropicnick", "13h", "Nobody has produced that data in three years of me asking. The manufacturers cite a study on nicotinamide riboside and hope you don’t check.", 27),
            l("me", "3d", "The first-pass argument convinced me — I switched to subq injections and the subjective difference was obvious.", 8),
            l("skeptical_sam", "10h", "‘Subjective difference was obvious’ is exactly what you’d expect from switching to a route with a strong physical sensation, though.", 22),
            l("dramaraokafor", "8h", "Both things can be true. The route probably is better absorbed *and* the flush makes it feel like more than it is.", 31),
            l("drsarahchen", "6h", "This is the version of this argument I wish happened more often on here.", 26),
        ]),
        ("s10", [
            l("nootropicnick", "13h", "Prices near me: IV clinic $250–400 a session, injections about $2 a day equivalent, NMN maybe $30 a month. The gap is enormous and I can’t justify the top end.", 24),
            l("dramaraokafor", "11h", "You’re paying for a bag, a chair and a nurse. Whether the route buys you anything over subq is not established, and the clinics are not the ones who will establish it.", 38),
            l("drtomhalloran", "9h", "Precursors are the only arm of this with a real human literature behind them, and even there the outcome data is thin. It’s also the cheapest. Draw your own conclusion.", 33),
            l("dosingdiary", "7h", "Did IV for three months. Best thing about it was that I sat still for an hour with my phone away.", 29),
            l("nootropicnick", "5h", "Genuinely might be the active ingredient.", 41),
            l("quietprotocol", "3h", "The clinic near me markets it for hangovers and long COVID in the same brochure, which told me everything.", 22),
        ]),
        ("s13", [
            l("dramaraokafor", "2d", "The evidence points to extracellular degradation by CD38 and NT5E, then re-synthesis from the precursors intracellularly. Which, if right, means injecting NAD+ is an expensive way to deliver NMN.", 44),
            l("drmarcuswebb", "2d", "There’s some transporter work suggesting direct uptake in specific tissues, but it’s cell-line data and I wouldn’t build a protocol on it.", 31),
            l("dramaraokafor", "1d", "Agreed — I’d call it unresolved rather than settled, but the burden is on the direct-uptake claim.", 27),
            l("nootropicnick", "1d", "So the honest position is: if the degradation story holds, the whole NAD+ injection industry is a delivery system for cheaper molecules.", 36),
            l("skeptical_sam", "22h", "And notably it’s the expensive version that gets marketed hardest.", 29),
            l("dramaraokafor", "18h", "I’d rather people took the mechanism seriously than the marketing, in either direction. It might turn out to matter which one you inject.", 24),
        ]),
        ("s16", [
            l("labratlife", "3d", "For anyone landing here from search: pushing over ~10 minutes instead of ~2 removed it almost entirely for me.", 26),
            l("drsarahchen", "3d", "The flush itself is vasodilation and generally benign. Nausea and chest tightness alongside it are a different conversation and worth stopping for.", 38),
            l("dosingdiary", "2d", "Mine came with a headache for the first three sessions and then stopped happening altogether. Tolerance, presumably.", 19),
            l("rn_dayshift", "2d", "Slow push, sitting down, not first thing on an empty stomach. Same advice we give for anything that drops blood pressure.", 31),
            l("nootropicnick", "1d", "The clinics lean into the flush as evidence that ‘it’s working’, which is worth being cynical about.", 27),
        ]),
        ("s21", [
            l("dosingdiary", "20h", "Two weeks of 1am wide-awake, switched to 7am dosing, sleeping normally within three days. Nothing else changed.", 28),
            l("dramaraokafor", "18h", "Plausible mechanistically — NAD+ metabolism is entangled with the circadian machinery, and there’s decent animal work on the loop running in both directions.", 34),
            l("rn_dayshift", "16h", "Anecdotally this is the single most common complaint I hear and morning dosing fixes most of it.", 26),
            l("quietprotocol", "12h", "Same experience, though I also cut my afternoon coffee in the same week, so my data is worthless.", 17),
            l("skeptical_sam", "9h", "At least you noticed the confound. That puts you ahead of most posts here.", 23),
            l("dosingdiary", "6h", "For what it’s worth I didn’t change anything else, and I went back to evening dosing once to check. Wired again that night.", 31),
        ]),
        ("s25", [
            l("skeptical_sam", "2d", "To be clear I’m not saying it does nothing. I’m saying a strong somatic cue is the ideal conditions for expectancy effects, and nobody here controls for it.", 37),
            l("dramaraokafor", "2d", "It’s a good question and the answer is that you can’t easily blind a flush. Which is exactly why the subjective reports in this category should be weighted lightly.", 42),
            l("nootropicnick", "1d", "I tried alternating saline and NAD+ blind with my partner preparing the syringes. I guessed correctly every time — because of the flush. So, useless.", 33),
            l("drsarahchen", "1d", "That’s a genuinely well-designed attempt that hit the exact wall Amara described. Nice try though.", 29),
            l("dosingdiary", "22h", "The only honest self-experiment I’ve seen here in months.", 21),
            l("skeptical_sam", "18h", "Which is why I keep asking. Not to be tiresome — I want someone to find a way around it.", 26),
        ]),
        ("s29", [
            l("rn_dayshift", "5d", "Rotating roster, so ‘dose in the morning’ is meaningless. What I settled on: dose at the start of my waking period, whatever the clock says.", 22),
            l("dosingdiary", "4d", "That’s the right anchor. Wake time, not clock time — same principle as light exposure.", 26),
            l("dramaraokafor", "4d", "Consistent relative to your own sleep-wake cycle is the best you can do, and shift work is going to be a bigger variable than the timing anyway.", 31),
            l("quietprotocol", "3d", "Six years of nights: nothing I took mattered as much as blackout curtains.", 34),
            l("rn_dayshift", "2d", "Depressingly true and much cheaper.", 28),
        ]),
    ]

    // MARK: - Your profile

    static let myQuestions: [FeedQuestion] = mine.map(withTrueAnswerCount)

    private static let mine: [FeedQuestion] = [
        me("m1", "BPC-157", "2d", "Best injection sites for BPC-157 — does local vs systemic matter?",
           "Trying to decide between injecting near the injury vs subq in the belly. Does site actually change outcomes?", 8, 12),
        me("m2", "Semaglutide", "3d", "Anyone compared reconstituted shelf life at 4°C vs frozen aliquots?",
           "Want to reconstitute once and store. Is freezing aliquots meaningfully better than just keeping it in the fridge?", 14, 9),
        me("m3", "NAD+", "1w", "What’s a sane baseline blood panel before starting a first stack?",
           "Before touching any of this I want labs. What’s the minimal panel people actually check first?", 22, 31),
        me("m4", "TB-500", "2w", "Is there any point cycling TB-500, or is continuous fine?",
           "Most protocols say loading phase then maintenance. Is the cycling based on anything real?", 6, 7),
        me("m5", "BPC-157", "3w", "How do you decide something isn’t working and stop?",
           "Six weeks in and I genuinely can’t tell. What’s everyone’s stopping rule — and did you set it in advance?", 19, 44),
        me("m6", "Semaglutide", "1mo", "Is there a good reason to take a break, or is that just diet-culture logic?",
           "Keep seeing ‘cycle off’ advice with no rationale attached. Is there an actual pharmacological argument?", 11, 16),
    ]

    static let myReplies: [MyReply] = [
        MyReply(to: "Does BPC-157 actually help tendon healing?",
                text: "In my experience local injection near the tendon helped more than systemic — but I was also loading hard, so grain of salt.",
                time: "1d", parent: question("s1")),
        MyReply(to: "How are you handling week-one semaglutide nausea?",
                text: "Splitting the dose timing and eating my last meal earlier basically fixed it for me by day 4.",
                time: "2d", parent: question("s3")),
        MyReply(to: "Is sublingual NAD+ absorption actually meaningful?",
                text: "The first-pass argument convinced me — I switched to subq injections and the subjective difference was obvious.",
                time: "3d", parent: question("s5")),
        MyReply(to: "TB-500 stacking with BPC-157 — redundant or synergistic?",
                text: "Ran both for 5 weeks. Can’t give you a controlled answer, but recovery felt faster than either alone.",
                time: "4d", parent: question("s6")),
        MyReply(to: "Plateaued at month 4 on semaglutide — titrate up or add something?",
                text: "Went through this at almost exactly the same point. Held the dose, it moved again three weeks later.",
                time: "5d", parent: question("s12")),
        MyReply(to: "PT here: what I actually see in clinic when people come in on peptides",
                text: "This reframed how I think about the whole category, honestly. Saving it.",
                time: "1w", parent: question("s28")),
    ]

    /// Conversations under your own questions — tapping through from the
    /// profile has to land somewhere real too.
    private static let myThreads: [(String, [Line])] = [
        ("m1", [
            l("drsarahchen", "2d", "There’s no outcome data separating the two in humans. The local-injection rationale is that you’re after a tissue concentration you can’t reach systemically — reasonable, unproven.", 26),
            l("tendonrehab", "1d", "Local, near the insertion, made a visible difference for me versus subq the previous round. Same caveats as always.", 18),
            l("drelenaruiz", "1d", "If you go local, know your anatomy or have someone who does. Injecting into a tendon rather than around it is a real way to make things worse.", 34),
            l("peptidenotes", "22h", "Most reported protocols split the difference — near the site but into subcutaneous tissue, not the structure itself.", 14),
        ]),
        ("m2", [
            l("drtomhalloran", "3d", "Frozen aliquots for anything past a month, fridge for what you’re actively using. Avoid freeze-thaw cycles — that’s what actually degrades it, not the storage itself.", 31),
            l("labratlife", "2d", "Aliquot before you freeze so you’re never thawing the same vial twice. Cheap syringes, one dose each.", 24),
            l("rn_dayshift", "2d", "And label them. Three identical unlabelled syringes in a freezer is a problem waiting to happen.", 19),
        ]),
        ("m3", [
            l("drpriyanair", "1w", "The panel I’d want before anything: CBC, CMP, HbA1c, fasting lipids, hs-CRP, and a thyroid panel. That’s not exotic and any lab will run it.", 48),
            l("drsarahchen", "1w", "Add a baseline you can actually compare against later. A panel with nothing to compare it to is only half useful.", 39),
            l("labratlife", "6d", "About $180 direct-order where I am. Cheapest part of the whole exercise and the only part that generates data.", 27),
            l("skeptical_sam", "6d", "This should be the first thing anyone reads when they join, honestly.", 33),
            l("quietprotocol", "5d", "Repeat at 8–12 weeks or it’s just a number in a drawer.", 21),
        ]),
        ("m4", [
            l("peptidenotes", "2w", "The loading-then-maintenance structure comes from the original vendor literature, not from a study. I’ve never found a citation for it.", 22),
            l("dramaraokafor", "2w", "Correct — there’s no pharmacokinetic rationale for the specific schedules people quote. They’ve simply been repeated for a decade.", 29),
            l("drelenaruiz", "1w", "Which doesn’t mean continuous is better. It means nobody has tested either, so pick the one that’s easier to stick to.", 25),
        ]),
        ("m5", [
            l("drelenaruiz", "3w", "Set the stopping rule before you start, and make it a measure rather than a feeling. Pain on a specific loaded movement, range in degrees, something you can write down.", 41),
            l("coachdana", "3w", "Six weeks with no measurable change on the thing you’re actually trying to fix is a reasonable stop for most people.", 33),
            l("skeptical_sam", "2w", "The reason this question is hard is that the honest answer is uncomfortable: most people never set a rule, so they never stop.", 37),
            l("mira_lifts", "2w", "I stopped at seven weeks and only found out it had worked by the six-month mark. Stopping isn’t the same as concluding it failed.", 28),
        ]),
        ("m6", [
            l("drpriyanair", "1mo", "There’s no pharmacological argument for routine breaks that I’m aware of. It’s a chronic-condition medication and it’s modelled that way in the trials.", 34),
            l("drtomhalloran", "1mo", "The ‘cycling’ language is imported wholesale from a different category. It doesn’t map onto this one.", 27),
            l("glp1journey", "3w", "Went off for two months and regained most of it. That’s the actual answer for a lot of people and nobody enjoys hearing it.", 31),
        ]),
    ]

    // MARK: - Notifications

    static let activity: [ActivityItem] = [
        ActivityItem(id: "n1", initials: "SC", avatarHex: g1, actor: "Dr. Sarah Chen", time: "1h",
                     kind: .reply(preview: "There’s no outcome data separating the two in humans. The local-injection…"), read: false),
        ActivityItem(id: "n2", initials: "TR", avatarHex: g5, actor: "tendonrehab", time: "3h",
                     kind: .mention(preview: "…like @jake said, the loading is doing half the work here."), read: false),
        ActivityItem(id: "n3", initials: "GJ", avatarHex: g4, actor: "glp1journey", time: "5h",
                     kind: .follow, read: false),
        ActivityItem(id: "n4", initials: "ER", avatarHex: g7, actor: "Dr. Elena Ruiz", time: "7h",
                     kind: .reply(preview: "If you go local, know your anatomy or have someone who does…"), read: false),
        ActivityItem(id: "n5", initials: "", avatarHex: topicGrey, actor: "", time: "9h",
                     kind: .milestone("Your question passed 100 views"), read: false),
        ActivityItem(id: "n6", initials: "PN", avatarHex: g2, actor: "Dr. Priya Nair", time: "1d",
                     kind: .reply(preview: "The panel I’d want before anything: CBC, CMP, HbA1c, fasting lipids…"), read: true),
        ActivityItem(id: "n7", initials: "LL", avatarHex: g4, actor: "labratlife", time: "1d",
                     kind: .reply(preview: "Freezing aliquots is worth it past ~4 weeks in my testing."), read: true),
        ActivityItem(id: "n8", initials: "", avatarHex: topicGrey, actor: "", time: "1d",
                     kind: .digest(topic: "BPC-157", count: 12), read: true),
        ActivityItem(id: "n9", initials: "SS", avatarHex: g1, actor: "skeptical_sam", time: "2d",
                     kind: .mention(preview: "…@jake asked the same thing last week and got a better answer."), read: true),
        ActivityItem(id: "n10", initials: "PP", avatarHex: g6, actor: "peptidepete", time: "2d",
                     kind: .follow, read: true),
        ActivityItem(id: "n11", initials: "MW", avatarHex: g2, actor: "Dr. Marcus Webb", time: "3d",
                     kind: .reply(preview: "Worth separating pharmacokinetics from outcomes here…"), read: true),
        ActivityItem(id: "n12", initials: "", avatarHex: topicGrey, actor: "", time: "3d",
                     kind: .milestone("Your reply was vouched 25 times"), read: true),
        ActivityItem(id: "n13", initials: "ML", avatarHex: g5, actor: "mira_lifts", time: "4d",
                     kind: .follow, read: true),
        ActivityItem(id: "n14", initials: "", avatarHex: topicGrey, actor: "", time: "5d",
                     kind: .digest(topic: "Semaglutide", count: 9), read: true),
        ActivityItem(id: "n15", initials: "TH", avatarHex: g8, actor: "Dr. Tom Halloran", time: "6d",
                     kind: .reply(preview: "Frozen aliquots for anything past a month, fridge for what you’re using…"), read: true),
        ActivityItem(id: "n16", initials: "", avatarHex: topicGrey, actor: "", time: "1w",
                     kind: .digest(topic: "NAD+", count: 7), read: true),
    ]

    // MARK: - Your account

    /// Seeded into `AppModel` when the fixtures are on, so the profile,
    /// settings and topic filters aren't looking at an empty account.
    static let myHandle = "jake"
    static let myPhone = "+1 (917) 555-0148"
    static let myFollowedTopics: Set<String> = [
        "BPC-157", "TB-500", "Semaglutide", "NAD+", "Tirzepatide", "MOTS-c",
    ]

    /// Two accounts you've already blocked — Settings → Blocked accounts.
    static let blocked: [BlockedUser] = [
        BlockedUser(id: "blk1", handle: "gainzvendor_official"),
        BlockedUser(id: "blk2", handle: "peptidedeals24"),
    ]

    // MARK: - builders

    private static func question(_ id: String) -> FeedQuestion? {
        feed.first(where: { $0.id == id })
    }

    private static func q(_ id: String, _ who: String, _ topic: String, _ time: String,
                          _ title: String, _ preview: String, _ answers: Int, _ likes: Int,
                          _ attachment: FeedAttachment? = nil) -> FeedQuestion {
        let p = person(who)
        return FeedQuestion(id: id, authorId: p.id, topic: topic, hex: topicGrey, time: time,
                            title: title, preview: preview, author: p.name, initials: p.initials,
                            avatarHex: p.hex, badge: p.badge, answers: answers, likes: likes,
                            attachment: attachment)
    }

    private static func me(_ id: String, _ topic: String, _ time: String, _ title: String,
                           _ preview: String, _ answers: Int, _ likes: Int) -> FeedQuestion {
        FeedQuestion(id: id, authorId: "me", topic: topic, hex: topicGrey, time: time, title: title,
                     preview: preview, author: "you", initials: "JP", avatarHex: myGrey,
                     badge: nil, answers: answers, likes: likes, isMine: true)
    }
}
