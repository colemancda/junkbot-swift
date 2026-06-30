# JunkbotCore Translation Review

Generated from translated Swift headers and original Lingo files

## Summary

- Translated Swift files reviewed: 97
- Swift files changed: 95
- Original files missing: 0
- Original handlers without a matching Swift function/init name: 8
- Stub/TODO/commented pending lines: 61

## Handler Coverage

| Swift file | Original file | Original handlers | Commented matches | Pending name matches |
| --- | --- | ---: | ---: | ---: |
| `Sources/JunkbotCore/Catalog/Behavior21.swift` | `catalog/behavior_21.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorCatalogDevButton.swift` | `catalog/behavior_catalog dev button behavior.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorCatalogDisableUntilNetReady.swift` | `catalog/behavior_catalog disable until net ready.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorCatalogHyperlink.swift` | `catalog/behavior_catalog-hyperlink beh.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorCatalogLocalCheckbox.swift` | `catalog/behavior_catalog local checkbox behavior.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorCatalogSaveButton.swift` | `catalog/behavior_catalog save button beh.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorClearFieldOnBegin.swift` | `catalog/behavior_clear field on begin.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Catalog/BehaviorEntryField.swift` | `catalog/behavior_entry field beh.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Catalog/CatalogManager.swift` | `catalog/parent_catalog manager.ls` | 11 | 11 | 0 |
| `Sources/JunkbotCore/Dynamic/CastKeynumInput.swift` | `dynamic/cast_keynum_input.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorBgEditItem.swift` | `editor/behavior_editor-bg edit item.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorChooseColor.swift` | `editor/behavior_editor-choose color.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorColorableMenuItem.swift` | `editor/behavior_editor-colorable menu item.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorEditConfigBtn.swift` | `editor/behavior_editor-edit config btn.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorRegisterSprite.swift` | `editor/behavior_editor-register sprite beh.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorSelectableTool.swift` | `editor/behavior_editor-selectable tool.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorEditorToolHighlightBox.swift` | `editor/behavior_editor-tool highlight box beh.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Editor/BehaviorSignRegister.swift` | `editor/behavior_sign register behavior.ls` | 4 | 4 | 0 |
| `Sources/JunkbotCore/Editor/CastConfigurePartButton.swift` | `editor/cast_configure part button.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Editor/EditManager.swift` | `editor/parent_edit manager.ls` | 11 | 11 | 0 |
| `Sources/JunkbotCore/Editor/PlayfieldManager.swift` | `editor/parent_playfield manager.ls` | 45 | 45 | 0 |
| `Sources/JunkbotCore/Internal/Behavior40.swift` | `Internal/behavior_40.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorAuthorModeVisToggle.swift` | `Internal/behavior_authorMode_vis_toggle.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorConfigManager.swift` | `Internal/behavior_config manager.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorDisplayText.swift` | `Internal/behavior_Display Text.ls` | 15 | 14 | 1 |
| `Sources/JunkbotCore/Internal/BehaviorFrameloop.swift` | `screens_by_peter/behavior_frameloop.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorGameInterfaceButtons.swift` | `screens_by_peter/behavior_game_interface_buttons.ls` | 5 | 5 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorGameLoop.swift` | `Internal/behavior_game_loop.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorGlobalButton.swift` | `Internal/behavior_global button.ls` | 2 | 1 | 1 |
| `Sources/JunkbotCore/Internal/BehaviorKeyboardEquivalent.swift` | `Internal/behavior_keyboard equivalent.ls` | 2 | 1 | 1 |
| `Sources/JunkbotCore/Internal/BehaviorLegopartsManager.swift` | `Internal/behavior_legoparts manager.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorPartClick.swift` | `Internal/behavior_part click behavior.ls` | 4 | 4 | 0 |
| `Sources/JunkbotCore/Internal/BehaviorSetMyLocZ.swift` | `screens_by_peter/behavior_set my locz.ls` | 2 | 1 | 1 |
| `Sources/JunkbotCore/Internal/BehaviorTooltip.swift` | `Internal/behavior_Tooltip.ls` | 18 | 17 | 1 |
| `Sources/JunkbotCore/Internal/BehaviorUseSnumForLocZ.swift` | `Internal/behavior_useSnumForLocZ.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/DatabaseManager.swift` | `Internal/parent_database manager.ls` | 13 | 13 | 0 |
| `Sources/JunkbotCore/Internal/MovieDebuggingUtility.swift` | `Internal/movie_Debugging Utility Functions.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Internal/MovieMain.swift` | `Internal/movie_main.ls` | 17 | 17 | 0 |
| `Sources/JunkbotCore/Internal/MovieSoundCode.swift` | `Internal/movie_Sound Code.ls` | 8 | 8 | 0 |
| `Sources/JunkbotCore/Internal/MovieTemp.swift` | `Internal/movie_temp.ls` | 0 | 0 | 0 |
| `Sources/JunkbotCore/Loading/DownloadManager.swift` | `loading/parent_download manager.ls` | 11 | 11 | 0 |
| `Sources/JunkbotCore/Peter101/BehaviorBossMemo.swift` | `peter 101/behavior_BossMemo_script.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Peter101/BehaviorHideBossMessage.swift` | `peter 101/behavior_HideBossMessage.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Peter101/BehaviorStartButton.swift` | `peter 101/behavior_STARTBUTTON.ls` | 5 | 5 | 0 |
| `Sources/JunkbotCore/Peter101/Movie42.swift` | `peter 101/movie_42.ls` | 0 | 0 | 0 |
| `Sources/JunkbotCore/Play/BehaviorMasterBoxOut.swift` | `play/behavior_Master.Box.Out.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Play/GameManager.swift` | `play/parent_game manager.ls` | 20 | 20 | 0 |
| `Sources/JunkbotCore/Play/HazardClimbParent.swift` | `play/parent_hazard climb parent.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Play/HazardDripParent.swift` | `play/parent_hazard drip parent.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Play/HazardDumbfloatParent.swift` | `play/parent_hazard dumbfloat parent.ls` | 4 | 4 | 0 |
| `Sources/JunkbotCore/Play/HazardFloatParent.swift` | `play/parent_hazard float parent.ls` | 4 | 4 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickFanParent.swift` | `play/parent_hazard slick fan parent.ls` | 7 | 7 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickFireParent.swift` | `play/parent_hazard slick fire parent.ls` | 7 | 7 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickJumpParent.swift` | `play/parent_hazard slick jump parent.ls` | 8 | 8 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickPipeParent.swift` | `play/parent_hazard slick pipe parent.ls` | 7 | 7 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickShieldParent.swift` | `play/parent_hazard slick shield parent.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Play/HazardSlickSwitchParent.swift` | `play/parent_hazard slick switch parent.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Play/HazardWalkParent.swift` | `play/parent_hazard walk parent.ls` | 6 | 6 | 0 |
| `Sources/JunkbotCore/Play/MinifigWalkParent.swift` | `play/parent_minifig walk parent.ls` | 10 | 10 | 0 |
| `Sources/JunkbotCore/Play/PlayManager.swift` | `play/parent_play manager.ls` | 17 | 17 | 0 |
| `Sources/JunkbotCore/Screens/Behavior127.swift` | `screens_by_peter/behavior_127.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/Behavior27.swift` | `screens_by_peter/behavior_27.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/Behavior33.swift` | `screens_by_peter/behavior_33.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Screens/Behavior91.swift` | `screens_by_peter/behavior_91.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorButtonHelp.swift` | `screens_by_peter/behavior_button-help.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorButtonMain.swift` | `screens_by_peter/behavior_button_Main.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorButtonsRo.swift` | `screens_by_peter/behavior_buttons_ro.ls` | 5 | 5 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorCreditsButton.swift` | `screens_by_peter/behavior_credits button.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorDontPassOnMemo.swift` | `screens_by_peter/behavior_Don'tPass on Memo.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorGoMenu.swift` | `screens_by_peter/behavior_go menu.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorGoNext.swift` | `screens_by_peter/behavior_go next.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorGoPrev.swift` | `screens_by_peter/behavior_go prev.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorGoldAwardNavBar.swift` | `screens_by_peter/behavior_Code for Gold Award info on Nav bar.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorHOFDisplay.swift` | `screens_by_peter/behavior_HOF_display behavior.ls` | 5 | 5 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorHOFPageButtons.swift` | `screens_by_peter/behavior_hof page buttons behavior.ls` | 8 | 7 | 1 |
| `Sources/JunkbotCore/Screens/BehaviorHideHOFAnim.swift` | `screens_by_peter/behavior_hide_HOF_anim.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorHideRankBox.swift` | `screens_by_peter/behavior_HideRankBox.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorHintOKBox.swift` | `screens_by_peter/behavior_Hint_OK_Box.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorLevelEndDialogButtons.swift` | `screens_by_peter/behavior_level end dialog buttons behavior.ls` | 3 | 2 | 1 |
| `Sources/JunkbotCore/Screens/BehaviorListRoHiLite.swift` | `screens_by_peter/behavior_ListRoHiLite.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxFail.swift` | `screens_by_peter/behavior_msgBox_Fail.ls` | 9 | 9 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxGetPlaque.swift` | `screens_by_peter/behavior_msgBox_GetPlaque (award).ls` | 11 | 11 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxHint.swift` | `screens_by_peter/behavior_msgBox_HINT.ls` | 10 | 10 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxIntoHallOfFame.swift` | `screens_by_peter/behavior_msgBox_IntoHallOfFame.ls` | 9 | 9 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxSuccess.swift` | `screens_by_peter/behavior_msgBox_Success.ls` | 11 | 11 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorMsgBoxTitle.swift` | `screens_by_peter/behavior_msgBox_Title.ls` | 10 | 10 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorOKHallOfFame.swift` | `screens_by_peter/behavior_OK-hall-of-fame.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorPlaqueSelfControl.swift` | `screens_by_peter/behavior_plaque_self_control_code.ls` | 2 | 2 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorRankMeter.swift` | `screens_by_peter/behavior_rankMeter_code.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorScreenLoop.swift` | `screens_by_peter/behavior_screen_loop.ls` | 10 | 10 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorSelfUpdatePortrait.swift` | `screens_by_peter/behavior_self-update_portrait.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorShowHint.swift` | `screens_by_peter/behavior_ShowHint.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/BehaviorUpdateTotalMoves.swift` | `screens_by_peter/behavior_UpdateTotalMoves.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/MovieDummyDataManager.swift` | `screens_by_peter/movie_dummy_data_manager.ls` | 3 | 3 | 0 |
| `Sources/JunkbotCore/Screens/ScreensBehaviorFrameloop.swift` | `screens_by_peter/behavior_frameloop.ls` | 1 | 1 | 0 |
| `Sources/JunkbotCore/Screens/ScreensBehaviorGameInterfaceButtons.swift` | `screens_by_peter/behavior_game_interface_buttons.ls` | 5 | 5 | 0 |
| `Sources/JunkbotCore/Screens/ScreensBehaviorSetMyLocZ.swift` | `screens_by_peter/behavior_set my locz.ls` | 2 | 1 | 1 |

## Pending Original Handlers Without Matching Swift Names

- `Sources/JunkbotCore/Internal/BehaviorDisplayText.swift`: original handler `getpropertydescriptionlist` from `Internal/behavior_Display Text.ls`
- `Sources/JunkbotCore/Internal/BehaviorGlobalButton.swift`: original handler `getpropertydescriptionlist` from `Internal/behavior_global button.ls`
- `Sources/JunkbotCore/Internal/BehaviorKeyboardEquivalent.swift`: original handler `getpropertydescriptionlist` from `Internal/behavior_keyboard equivalent.ls`
- `Sources/JunkbotCore/Internal/BehaviorSetMyLocZ.swift`: original handler `getpropertydescriptionlist` from `screens_by_peter/behavior_set my locz.ls`
- `Sources/JunkbotCore/Internal/BehaviorTooltip.swift`: original handler `getpropertydescriptionlist` from `Internal/behavior_Tooltip.ls`
- `Sources/JunkbotCore/Screens/BehaviorHOFPageButtons.swift`: original handler `getpropertydescriptionlist` from `screens_by_peter/behavior_hof page buttons behavior.ls`
- `Sources/JunkbotCore/Screens/BehaviorLevelEndDialogButtons.swift`: original handler `getpropertydescriptionlist` from `screens_by_peter/behavior_level end dialog buttons behavior.ls`
- `Sources/JunkbotCore/Screens/ScreensBehaviorSetMyLocZ.swift`: original handler `getpropertydescriptionlist` from `screens_by_peter/behavior_set my locz.ls`

## Stub / TODO / Skipped Translation Lines

- `Sources/JunkbotCore/DirectorStubs.swift`:24: return (n > 1) ? (1 + (currentTicks % n)) : 1  // deterministic stub
- `Sources/JunkbotCore/DirectorStubs.swift`:61: // Stubbed sound effect playback
- `Sources/JunkbotCore/Loading/DownloadManager.swift`:53: // debug stub — no-op
- `Sources/JunkbotCore/Catalog/CatalogManager.swift`:70: // current_level is accessed via LV glob; stub this side-effect
- `Sources/JunkbotCore/Catalog/CatalogManager.swift`:313: // cattext?.setHyperlink(hl, forLine: i + 1) -- stub
- `Sources/JunkbotCore/Catalog/BehaviorCatalogLocalCheckbox.swift`:33: // catalog_manager.localmode is accessed via LV dynamic lookup — stub
- `Sources/JunkbotCore/Internal/BehaviorLegopartsManager.swift`:351: // Stub: image splitting would be performed using platform image APIs
- `Sources/JunkbotCore/Internal/BehaviorDisplayText.swift`:82: // mySprite.visible = 1  (stub: set sprite visible)
- `Sources/JunkbotCore/Internal/BehaviorDisplayText.swift`:175: // Stub: would measure text dimensions via member API
- `Sources/JunkbotCore/Internal/BehaviorDisplayText.swift`:423: return false  // stub
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:45: // Stub: platform sound API integration needed
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:72: // Stub: platform sound API integration needed.
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:110: // Stub: platform sound API integration needed.
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:148: // Stub: platform sound API integration needed.
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:167: // Stub: return 0 until member text is accessible.
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:191: // Stub: platform sound API integration needed.
- `Sources/JunkbotCore/Internal/MovieSoundCode.swift`:228: // Stub: platform sound API (e.g. AVAudioPlayer) integration needed.
- `Sources/JunkbotCore/Internal/BehaviorTooltip.swift`:214: // displayLoc = the mouseLoc (stub)
- `Sources/JunkbotCore/Internal/BehaviorTooltip.swift`:228: // stub: send DisplayText_SetText to enrolled display behaviors
- `Sources/JunkbotCore/Internal/BehaviorTooltip.swift`:247: // stub: clear display text
- `Sources/JunkbotCore/Screens/BehaviorMsgBoxSuccess.swift`:539: // Image compositing stub — sets up key icon strip
- `Sources/JunkbotCore/Play/PlayManager.swift`:93: // setLevel(Glob.shared.EDITOR.edit_manager.playfield_manager.current_level) -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:144: // config = Glob.shared["config_manager"].asObject()?.parseParams(confStr) -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:151: // if config["info"] != nil { member("level title")?.text = ... } -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:172: Glob.shared["partclick_recipient"] = .void  // stub: store self reference
- `Sources/JunkbotCore/Play/PlayManager.swift`:193: Glob.shared["partclick_recipient"] = .void  // stub: store self reference
- `Sources/JunkbotCore/Play/PlayManager.swift`:309: // member("play status field")?.text = t -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:310: // member("play move counter field")?.text = String(gamestatus["#moves"].asInt ?? 0) -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:323: // repeat with part in playfield_manager.getPartsByLabel(args["label"]) { part.behavior.notify(["switch": args["state"]]) } -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:339: // movePieceGroup sprite manipulation -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:510: // if Glob.shared.EDITOR["drag_sprite"] == nil { return } -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:511: // if playfield_manager == nil { return } -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:515: // a.stepFrame() -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:553: let everythingPlaceable = 1 // Simplified stub for dragging
- `Sources/JunkbotCore/Play/PlayManager.swift`:682: // playfield_manager.erasePieceGroup(movePieceGroup, 1) -- stub
- `Sources/JunkbotCore/Play/BehaviorMasterBoxOut.swift`:12: // Glob.shared["master_obj"].getOut() -- stub
- `Sources/JunkbotCore/Play/BehaviorMasterBoxOut.swift`:13: // Glob.shared["award_obj"].dropBox() -- stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:214: // stub: boundary check using pf_size
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:218: let pos_x = 0  // stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:219: let pos_y = 0  // stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:220: let mW = 0  // stub: playfield_manager.pf_size width
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:221: let mH = 0  // stub: playfield_manager.pf_size height
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:225: // myObj = playfield_manager.getPart(point(r, pos_y)) -- stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:226: let myObj: PropList? = nil  // stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:242: let myObj: PropList? = nil  // stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:258: let myObj: PropList? = nil  // stub
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:274: let myObj: PropList? = nil  // stub
- `Sources/JunkbotCore/Play/GameManager.swift`:72: let stubLevelText = "[info:[title:\"Stub Level\", hint:\"Walk to the exit!\", par:10], bricks:[[#BRICK_01, point(0,0)]]]"
- `Sources/JunkbotCore/Play/GameManager.swift`:74: let leveldata = (Glob.shared["config_manager"].asObject() as? BehaviorConfigManager)?.parseParams(stubLevelText) ?? PropList()
- `Sources/JunkbotCore/Play/GameManager.swift`:82: levelEntry["data"] = .string(stubLevelText)
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:98: // s = playfield_manager.getASprite() -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:99: // part.auxSprites["myDrip"] = s -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:100: // s.ink = 8 -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:101: // s.visible = 1 -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:125: // s.member = member("drip_falling_1") -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:126: // s.rect = s.member.rect -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:128: // s.member = member("drip_splashing_\(ds)") -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:129: // s.rect = s.member.rect -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:137: // s.loc = driploc -- stub
- `Sources/JunkbotCore/Play/HazardDripParent.swift`:138: // s.locZ = top_locz -- stub
- `Sources/JunkbotCore/Editor/BehaviorEditorBgEditItem.swift`:29: // Since we can't dynamic-call bg_edit_item on LV, stub this call out.
