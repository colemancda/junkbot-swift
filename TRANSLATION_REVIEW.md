# JunkbotCore Translation Review

Generated from translated Swift headers and original Lingo files

## Summary

- Translated Swift files reviewed: 97
- Swift files changed: 95
- Original files missing: 0
- Original handlers without a matching Swift function/init name: 8
- Stub/TODO/commented pending lines: 7

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

- `Sources/JunkbotCore/Play/PlayManager.swift`:332: // movePieceGroup sprite manipulation -- stub
- `Sources/JunkbotCore/Play/PlayManager.swift`:546: let everythingPlaceable = 1  // Simplified stub for dragging
- `Sources/JunkbotCore/Play/HazardFloatParent.swift`:214: // stub: boundary check using pf_size
- `Sources/JunkbotCore/Play/GameManager.swift`:72: let stubLevelText =
- `Sources/JunkbotCore/Play/GameManager.swift`:73: "[info:[title:\"Stub Level\", hint:\"Walk to the exit!\", par:10], bricks:[[#BRICK_01, point(0,0)]]]"
- `Sources/JunkbotCore/Play/GameManager.swift`:77: stubLevelText) ?? PropList()
- `Sources/JunkbotCore/Play/GameManager.swift`:85: levelEntry["data"] = .string(stubLevelText)
