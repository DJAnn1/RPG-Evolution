-- QuestConfig.lua - Place ONLY in ReplicatedStorage
local QuestConfig = {
	-- Quest definitions with all their properties
	quests = {
		quest1 = {
			displayName = "Basic Quest",
			npcDialogue = {"Hello! Welcome to Happy Home", "well, it would be happier if you killed those noobs."},
			completedDialogue = {"you already did the quest bozo", "bye"},
			activeQuestDialogue = {"you already got a quest dummy: %s", "finish it first so you can receive my superior quest"},
			enemiesRequired = 5,
			killEvent = "EnemyKilled",
			guiLocation = {arena = "arena1", frame = "quest1Frame", label = "quest1Text2"},
			npcName = "noobDialogue"
		},
		fishQuest1 = {
			displayName = "Fishman Quest",
			npcDialogue = {"These fishman below are an invasive species", "Help me clean em out."},
			completedDialogue = {"Thanks for helping out!"},
			activeQuestDialogue = {"Seems like ya already doing %s", "Finish that up so ye can assist thee!"},
			enemiesRequired = 5,
			killEvent = "fishmanKilled",
			guiLocation = {arena = "arena1", frame = "questFrame", label = "Text2"},
			npcName = "fishermanDialogue"
		},
		bossQuest1 = {
			displayName = "Boss Quest",
			npcDialogue = {"i am the leader of guests but i have a problem", "telamon is trying to erase me... please defeat him", "i heard he's hiding at roblox HQ"},
			completedDialogue = {"thank you for saving me.. i owe you"},
			activeQuestDialogue = {"it seems you're already doing %s", "you gotta finish it fast so you can save me!"},
			enemiesRequired = 1,
			killEvent = "telamonKilled",
			guiLocation = {arena = "arena1", frame = "bossQuest1Frame", label = "bossQuest1Text2"},
			npcName = "guestDialogue"
		},
		arabQuest1 = {
			displayName = "Desert Mobsters",
			npcDialogue = {"salam brother", "may you please kill these villagers?", "they punched my dog :("},
			completedDialogue = {"thank you brother.. may you find peace"},
			activeQuestDialogue = {"you're already doing some dirty american quest: %s", "finish it fast brother"},
			enemiesRequired = 10,
			killEvent = "arab1Killed",
			guiLocation = {arena = "arena1", frame = "questFrame", label = "Text2"},
			npcName = "arabDialogue"
		},
		arabQuest2 = {
			displayName = "Desert Bandit",
			npcDialogue = {"these guys are too nice", "teach em a lesson"},
			completedDialogue = {"hehe, you did well grasshopper"},
			activeQuestDialogue = {"you're already doing some dirty american quest: %s", "finish it fast brother"},
			enemiesRequired = 10,
			killEvent = "arab2Killed",
			guiLocation = {arena = "arena1", frame = "questFrame", label = "Text2"},
			npcName = "arabDialogue2"
		},
		arabQuest3 = {
			displayName = "Desert Peasant",
			npcDialogue = {"i don't like poor people", "teach em a lesson"},
			completedDialogue = {"hehe, you really are evil"},
			activeQuestDialogue = {"you're already doing some dirty american quest: %s", "finish it fast brother"},
			enemiesRequired = 10,
			killEvent = "arab3Killed",
			guiLocation = {arena = "arena1", frame = "questFrame", label = "Text2"},
			npcName = "arabDialogue3"
		},
		arabkingQuest1 = {
			displayName = "Arab King Quest",
			npcDialogue = {"Please... defeat my king", "Free us from his tyranny"},
			completedDialogue = {"looks like he just respawns nvm"},
			activeQuestDialogue = {"you're STILL doing %s?!", "HURRY AND FINISH!!"},
			enemiesRequired = 1,
			killEvent = "arabkingKilled",
			guiLocation = {arena = "arena1", frame = "questFrame", label = "Text2"},
			npcName = "arabDialogue4"
		},
		linkQuest1 = {
			displayName = "Link Quest",
			npcDialogue = {"Hey, listen!", "Ganondorf created evil clones of me and I need your help!", "Please defeat them.. "},
			completedDialogue = {"I owe you.. i'm sure you got pwned lots of times"},
			activeQuestDialogue = {"oh.. you're doing: %s", "i guess ganondorf will win D:"},
			enemiesRequired = 10,
			killEvent = "linkKilled",
			guiLocation = {arena = "arena2", frame = "linkQuest1Frame", label = "linkQuest1Text2"},
			npcName = "linkDialogue"
		},
		zombieQuest1 = {
			displayName = "Zombie Quest",
			npcDialogue = {"The horrors I have witnessed...", "I need them gone."},
			completedDialogue = {"They're still everywhere.. we're doomed."},
			activeQuestDialogue = {"You're doing..: %s?", "It'll be too late."},
			enemiesRequired = 10,
			killEvent = "zombieKilled",
			guiLocation = {arena = "arena2", frame = "questFrame", label = "Text2"},
			npcName = "zombieDialogue"
		},
		zombieBossQuest1 = {
			displayName = "Zombie Boss Quest",
			npcDialogue = {"..he's too strong..", "Please.. defeat him."},
			completedDialogue = {"*is dead*"},
			activeQuestDialogue = {"No.. no, %s isn't important right now!"},
			enemiesRequired = 1,
			killEvent = "zombieBossKilled",
			guiLocation = {arena = "arena2", frame = "questFrame", label = "Text2"},
			npcName = "zombieBossDialogue"
		},
		ghostQuest1 = {
			displayName = "Ghost Quest",
			npcDialogue = {"I have possessed this man.", "Think you can defeat us..?"},
			completedDialogue = {"nvm ur pretty strong"},
			activeQuestDialogue = {"You fool. You are already doing: %s?", "Pitiful."},
			enemiesRequired = 10,
			killEvent = "ghostKilled",
			guiLocation = {arena = "arena2", frame = "questFrame", label = "Text2"},
			npcName = "ghostDialogue"
		},
		ghostBossQuest1 = {
			displayName = "Ghost Boss Quest",
			npcDialogue = {"Hi!", "My friend lives in that house. He likes visitors :)"},
			completedDialogue = {"You think you defeated him? He always comes back."},
			activeQuestDialogue = {"Heh. You want to fight my friend but you're doing %s?", "He's gonna get jealous! :)"},
			enemiesRequired = 1,
			killEvent = "ghostBossKilled",
			guiLocation = {arena = "arena2", frame = "questFrame", label = "Text2"},
			npcName = "ghostBossDialogue"
		}
	},
	-- Special NPCs that don't give quests
	specialNPCs = {
		creatorDialogue = {
			dialogue = {"pssst.. hey kid, want a secret weapon?", "well, come back when the creator of the game thinks of something"}
		},
		resetLvlDialogue = {
			dialogue = {"yo you wanna reset your level?", "here ya go"},
			action = function(player)
				local resetLvlNPCEvent = game.ReplicatedStorage:WaitForChild("resetLevelNPC")
				resetLvlNPCEvent:FireServer()
			end
		}
	}
}

-- Cached values for performance
local questNames = nil
local killEventMapping = nil

-- Helper function to get quest config by name
function QuestConfig:GetQuest(questName)
	return self.quests[questName]
end

-- Helper function to get all quest names (cached)
function QuestConfig:GetAllQuestNames()
	if not questNames then
		questNames = {}
		for questName in pairs(self.quests) do
			table.insert(questNames, questName)
		end
	end
	return questNames
end

-- Helper function to get kill event mapping (cached)
function QuestConfig:GetKillEventMapping()
	if not killEventMapping then
		killEventMapping = {}
		for questName, questData in pairs(self.quests) do
			killEventMapping[questData.killEvent] = {
				questName = questName,
				enemiesRequired = questData.enemiesRequired
			}
		end
	end
	return killEventMapping
end

return QuestConfig