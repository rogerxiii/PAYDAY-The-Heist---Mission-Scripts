# PAYDAY: The Heist - Mission Scripts

Here a collection of all of PD:TH's mission scripts, converted to make reading and searching as easy as possible.

In _levels [raw]_ are the original mission scripts, which are just LUA tables.  
In _levels [compact]_ are the converted mission scripts. All elements that could be inlined are inlined and unreachable elements are removed.  
In _levels [full]_ are the converted missions scripts that are identical to the _compact_ ones, besides having added **every** element, in case something has been inlined but you need to find a reference to it.

[Here is an example of how to use this (#TODO)](https://www.unknowncheats.me/forum/payday-2-a/)



# List Of Mission Names

Not all the mission/level names make sense on first sight, so here is a quick and easy list:
```
First World Bank = 'bank'
Heat Street = 'street'
Panic Room = 'apartment'
Green Bridge = 'bridge'
Diamond Heist = 'diamondheist'
Slaughterhouse = 'slaughterhouse'
Counterfeit = 'suburbia'
Undercover = 'secret_stash'
No Mercy = 'l4d'
```



# Using The Script

The script is pretty self-explanatory. I have also included my personal expansive logging function which can log pretty much any data type in PD:TH (or 2) and which is used heavily in the converting script.
All the details about what element does what can be found in _(core/)lib/managers/mission_.



# List Of All Elements

If you're curious yourself about a certain feature, you can look up the elements yourself, this list contains all the (used) elements.
```
ElementAIGraph
ElementAIRemove
ElementActivateScript
ElementAiGlobalEvent
ElementAlertTrigger
ElementAreaMinPoliceForce
ElementAreaTrigger
ElementAwardAchievment
ElementBainState
ElementBlackscreenVariant
ElementBlurZone
ElementCharacterOutline
ElementCounter
ElementCounterReset
ElementDangerZone
ElementDebug
ElementDialogue
ElementDifficulty
ElementDifficultyLevelCheck
ElementDisableShout
ElementDisableUnit
ElementDropinState
ElementEnemyDummyTrigger
ElementEnemyPreferedAdd
ElementEnemyPreferedRemove
ElementEquipment
ElementExecuteInOtherMission
ElementExplosionDamage
ElementFakeAssaultState
ElementFeedback
ElementFilter
ElementFlashlight
ElementFleePoint
ElementGlobalEventTrigger
ElementHint
ElementKillZone
ElementLogicChance
ElementLogicChanceOperator
ElementLogicChanceTrigger
ElementLookAtTrigger
ElementMaskFilter
ElementMissionEnd
ElementMoney
ElementObjective
ElementOperator
ElementOverlayEffect
ElementPlayEffect
ElementPlaySound
ElementPlayerSpawner
ElementPlayerState
ElementPlayerStateTrigger
ElementPlayerStyle
ElementPointOfNoReturn
ElementRandom
ElementScenarioEvent
ElementSecretAssignment
ElementSequenceCharacter
ElementSetOutline
ElementSmokeGrenade
ElementSpawnCivilian
ElementSpawnCivilianGroup
ElementSpawnEnemyDummy
ElementSpawnEnemyGroup
ElementSpecialObjective
ElementSpecialObjectiveTrigger
ElementStopEffect
ElementTeammateComment
ElementTimer
ElementTimerOperator
ElementTimerTrigger
ElementToggle
ElementUnitSequence
ElementUnitSequenceTrigger
ElementWaypoint
ElementWhisperState
MissionScriptElement
```