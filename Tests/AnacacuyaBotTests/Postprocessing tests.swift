//
//  PostprocessingTests.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-22.
//

import Testing

import AnacacuyaBot



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
        
        let postprocessed = await example[...].postprocessed()
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
        
        let postprocessed = await example[...].postprocessed()
        #expect("""
            Sorry about that, @ninedd.
            
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
        
        let postprocessed = await example[...].postprocessed()
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
        
        let postprocessed = await example[...].postprocessed()
        #expect("" == postprocessed)
    }
}
