//
//  PostprocessingTests.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Testing

import AnacacuyaBot



// MARK: - No-ops (postprocessing does nothing

struct NoOpTests {
    
    @Test func emptyString() async throws {
        let example = ""
        let postprocessed = await example.postprocessed()
        #expect(postprocessed == example)
    }
    
    
    @Test func normalResponse() async throws {
        let example = """
            I think that's just how it was back in the day; I mean, this is 1980s technology we're talking about here.
            """
        let postprocessed = await example.postprocessed()
        #expect(postprocessed == example)
    }
}



// MARK: - Combinations

struct PostprocessingCombinationsTests {
    
    init() async {
        await setUpBot()
    }
    
    
    @Test func quotedAndSelfIntroductory() async throws {
        let example = """
            "@AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts."
            """
        
        let postprocessed = await example.postprocessed()
        #expect("""
            Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts.
            """
            == postprocessed)
    }
}



// MARK: - Self-introduction

struct SelfIntroductionTests {
    
    init() async {
        await setUpBot()
    }
    
    
    @Test func handle() async throws {
        let example = """
            @AnacacuyaBot: Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts.
            """
        
        let postprocessed = await example.postprocessed()
        #expect("""
            Interesting! Can you list the top ten reasons? I'm curious to hear your thoughts.
            """
            == postprocessed)
    }
    
    
    @Test func you() async throws {
        let example = """
            you:
            :) Yeah, that's true, it does have an old-world charm to it. The bicycle stands out against the modern buildings, and the cobblestones are really cool. It feels like a different era.
            """
        
        let postprocessed = await example.postprocessed()
        #expect("""
            :) Yeah, that's true, it does have an old-world charm to it. The bicycle stands out against the modern buildings, and the cobblestones are really cool. It feels like a different era.
            """
            == postprocessed)
    }
    
    
    @Test func multiYou() async throws {
        let example = """
            you:
            you:
            *raises eyebrows and chortles quietly to himself* Ah, @dogval. Your responses never fail to bring a smile to my face. 😄
            """
        
        let postprocessed = await example.postprocessed()
        #expect("""
            *raises eyebrows and chortles quietly to himself* Ah, dogval. Your responses never fail to bring a smile to my face. 😄
            """
            == postprocessed)
    }
}



// MARK: - Fake chat logs

struct FakeChatLogRemovalTests {
    
    @Test func keepingPreamble_1() async throws {
        let example = """
            it's all in the universe, right?
            
            9DF90F5D (@ninedd):
            but like sometimes it feels like you're just at a disadvantage compared to others who get more opportunities
            
            1. Lotte/Cinny (@darkkirb) says they've been on TV once and possibly twice.
            2. Djei (@djeidragon) shares about their experience with pop culture war.
            3. val (@dogval) talks about being in the news but not on live TV.
            4. AnacacuyaBot reflects, stating that it's all a part of life and universe.
            """
        
        let postprocessed = await example.postprocessed()
        #expect("it's all in the universe, right?" == postprocessed)
    }
    
    
    @Test func keepingPreamble_2() async throws {
        let example = """
            Sorry about that, @ninedd.
            
            We were discussing running openclaw on my macbook pro, and it seems like you joined in right as we were starting our chat!
            
            Djei (@djeidragon):
            I guess I'll have to let this go for now, thanks for your patience :P
            
            bentley (@bentleyracune):
            no worries! i'll keep trying on my own computer until it works out.
            
            Djei (@djeidragon):
            if anyone's still interested in hearing about the openclawing process, feel free to message me and I can explain further!
            
            bentley (@bentleyracune):
            yeah, thanks for offering @djeidragon
            """
        
        let postprocessed = await example.postprocessed()
        #expect("""
            Sorry about that, ninedd.
            
            We were discussing running openclaw on my macbook pro, and it seems like you joined in right as we were starting our chat!
            """
            == postprocessed)
    }
    
    
    @Test func withCommandAndLink() async throws {
        let example = """
            Djei (@djeidragon):
            /llama3@CraiyonArtBot how many rs in strawberry?
            
            Northstar✨ 칠성들 (@KyNorthstar):
            Oh gosh.. it just tells the bot to send console commands. That's terifying
            
            https://github.com/NousResearch/hermes-agent/blob/main/skills/apple/apple-reminders/SKILL.md
            """
        
        let postprocessed = await example.postprocessed()
        #expect("" == postprocessed)
    }
    
    
    @Test
    func withFakeImageReference() async throws {
        let example = """
            Djei (@djeidragon):
            yeah, they did it with the circular parts too. not sure if anyone actually used them
            
            Djei (@djeidragon):
            also I think that part of the map was made in 2016 or something
            
            [img-2]Djei (@djeidragon):
            Image attachment: The image shows a picture of the Gorbals, an area in Glasgow. The picture features two people walking along a street lined with old buildings and shops that appear to be closed. The background is dark and there are no clouds in the sky.
            gobals
            
            9DF90F5D (@ninedd):
            yeah I saw it somewhere else before but can't remember where now
            
            9DF90F5D (@ninedd):
            it looks like a map from 1976 or something?
            """
        
        let postprocessed = await example.postprocessed()
        #expect("" == postprocessed)
    }
}



// MARK: - No response generated

struct NoResponseGeneratedTests {
    
    init() async {
        await setUpBot()
    }
    
    
    @Test func pure() async throws {
        let example = "[no response generated]"
        
        let postprocessed = await example.postprocessed()
        #expect(.empty == postprocessed)
    }
    
    
    @Test func curly() async throws {
        let example = "{no response generated}"
        
        let postprocessed = await example.postprocessed()
        #expect(.empty == postprocessed)
    }
    
    
    @Test func parens() async throws {
        let example = "(no response generated)"
        
        let postprocessed = await example.postprocessed()
        #expect(.empty == postprocessed)
    }
}
