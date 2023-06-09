package states.options;

import meta.PlayerSettings;
import meta.instances.BGSprite;
import meta.Conductor;
import flixel.FlxCamera;
import meta.data.ClientPrefs;
import meta.instances.Alphabet;
import meta.instances.Character;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

using StringTools;

class NoteOffsetState extends MusicBeatState
{
	var boyfriend:Character;
	var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;

	var coolText:FlxText;
	var combo:FlxSprite;
	var rating:FlxSprite;
	var comboNums:FlxSpriteGroup;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var barPercent:Float = 0;

	var delayMin:Int = -1000;
	var delayMax:Int = 1000;

	var timeBarBG:FlxSprite;
	var timeBar:FlxBar;
	var timeTxt:FlxText;
	var beatText:Alphabet;
	var beatTween:FlxTween;

	var changeModeText:FlxText;

	override public function create()
	{
		// Cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		CustomFadeTransition.nextCamera = camOther;
		FlxG.camera.scroll.set(120, 130);

		persistentUpdate = true;
		FlxG.sound.pause();
		// Stage
		var bg:BGSprite = new BGSprite('stageback', -600, -200, .9, .9);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, .9, .9);

		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();

		add(stageFront);
		if (!ClientPrefs.getPref('lowQuality'))
		{
			var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, .9, .9);

			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();

			add(stageLight);
			var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, .9, .9);

			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();

			stageLight.flipX = true;
			add(stageLight);

			var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
			stageCurtains.setGraphicSize(Std.int(stageCurtains.width * .9));
			stageCurtains.updateHitbox();

			add(stageCurtains);
		}
		// Characters
		gf = new Character(400, 130, 'gf');

		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];

		boyfriend = new Character(770, 100, 'bf', true);

		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];

		add(gf);
		add(boyfriend);

		// Combo stuff
		var globalAntialiasing:Bool = ClientPrefs.getPref('globalAntialiasing');

		combo = new FlxSprite().loadGraphic(Paths.image('combo'));
		combo.cameras = [camHUD];

		combo.setGraphicSize(Std.int(combo.width * .5));
		combo.updateHitbox();

		combo.antialiasing = globalAntialiasing;
		add(combo);

		coolText = new FlxText(0, 0, 0, '', 32);

		coolText.screenCenter();
		coolText.x = FlxG.width * .35;

		rating = new FlxSprite().loadGraphic(Paths.image("funny"));
		rating.cameras = [camHUD];

		rating.setGraphicSize(Std.int(rating.width * .7));
		rating.updateHitbox();

		rating.antialiasing = globalAntialiasing;
		add(rating);

		comboNums = new FlxSpriteGroup();
		comboNums.cameras = [camHUD];

		add(comboNums);

		var seperatedScore:Array<Int> = [];
		for (_ in 0...3)
			seperatedScore.push(FlxG.random.int(0, 9));

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite(43 * daLoop).loadGraphic(Paths.image('num$i'));

			numScore.antialiasing = globalAntialiasing;
			numScore.cameras = [camHUD];

			comboNums.add(numScore);
			daLoop++;
		}

		dumbTexts = new FlxTypedGroup();
		dumbTexts.cameras = [camHUD];

		add(dumbTexts);

		createTexts();
		repositionCombo();

		// Note delay stuff

		beatText = new Alphabet(0, 0, 'Beat Hit!', true);

		beatText.scaleX = .6;
		beatText.scaleY = .6;

		beatText.x += 260;
		beatText.alpha = 0;

		beatText.acceleration.y = 250;
		beatText.visible = false;

		add(beatText);

		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		timeTxt.scrollFactor.set();

		timeTxt.borderSize = 2;
		timeTxt.visible = false;

		timeTxt.cameras = [camHUD];
		barPercent = ClientPrefs.getPref('noteOffset');

		updateNoteDelay();
		timeBarBG = new FlxSprite(0, timeTxt.y + 8).loadGraphic(Paths.image('timeBar'));

		timeBarBG.setGraphicSize(Std.int(timeBarBG.width * 1.2));
		timeBarBG.updateHitbox();

		timeBarBG.cameras = [camHUD];
		timeBarBG.screenCenter(X);

		timeBarBG.visible = false;
		timeBar = new FlxBar(0, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this, 'barPercent', delayMin,
			delayMax);

		timeBar.scrollFactor.set();

		timeBar.screenCenter(X);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);

		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.visible = false;

		timeBar.cameras = [camHUD];

		add(timeBarBG);
		add(timeBar);
		add(timeTxt);

		///////////////////////

		var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = .6;
		blackBox.cameras = [camHUD];
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);
		updateMode();

		Conductor.changeBPM(128);
		FlxG.sound.playMusic(Paths.music('offsetSong'), 1, true);

		super.create();
	}

	var holdTime:Float = 0;
	var onComboMenu:Bool = true;
	var holdingObjectType:String = '';

	var startMousePos:FlxPoint = new FlxPoint();
	var startComboOffset:FlxPoint = new FlxPoint();

	override public function update(elapsed:Float)
	{
		var addNum:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			addNum = 10;

		if (onComboMenu)
		{
			var controlArray:Array<Bool> = [
				FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN, FlxG.keys.justPressed.A,

				FlxG.keys.justPressed.D, FlxG.keys.justPressed.W, FlxG.keys.justPressed.S, FlxG.keys.justPressed.J, FlxG.keys.justPressed.L,

				FlxG.keys.justPressed.I, FlxG.keys.justPressed.K
			];

			var comboOffset:Array<Int> = ClientPrefs.getPref('comboOffset');
			if (controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if (controlArray[i])
					{
						switch (i)
						{
							case 0:
								comboOffset[0] -= addNum;
							case 1:
								comboOffset[0] += addNum;

							case 2:
								comboOffset[1] += addNum;
							case 3:
								comboOffset[1] -= addNum;

							case 4:
								comboOffset[2] -= addNum;
							case 5:
								comboOffset[2] += addNum;

							case 6:
								comboOffset[3] += addNum;
							case 7:
								comboOffset[3] -= addNum;

							case 8:
								comboOffset[4] -= addNum;
							case 9:
								comboOffset[4] += addNum;

							case 10:
								comboOffset[5] += addNum;
							case 11:
								comboOffset[5] -= addNum;
						}
					}
				}
				repositionCombo();
			}

			// probably there's a better way to do this but, oh well.
			if (FlxG.mouse.justPressed)
			{
				holdingObjectType = null;
				FlxG.mouse.getScreenPosition(camHUD, startMousePos);
				if (startMousePos.x - combo.x >= 0
					&& startMousePos.x - combo.x <= combo.width
					&& startMousePos.y - combo.y >= 0
					&& startMousePos.y - combo.y <= combo.height)
				{
					holdingObjectType = 'combo';
					startComboOffset.x = comboOffset[4];
					startComboOffset.y = comboOffset[5];
					// trace('wassup');
				}
				else if (startMousePos.x - rating.x >= 0 && startMousePos.y - rating.y >= 0 && startMousePos.y - rating.y <= rating.height)
				{
					holdingObjectType = 'rating';

					startComboOffset.x = comboOffset[0];
					startComboOffset.y = comboOffset[1];
					// trace('heya');
				}
				else if (startMousePos.x - comboNums.x >= 0
					&& startMousePos.x - comboNums.x <= comboNums.width
					&& startMousePos.y - comboNums.y >= 0
					&& startMousePos.y - comboNums.y <= comboNums.height)
				{
					holdingObjectType = 'numscore';
					startComboOffset.x = comboOffset[2];
					startComboOffset.y = comboOffset[3];
					// trace('yo bro');
				}
			}
			if (FlxG.mouse.justReleased)
			{
				holdingObjectType = null;
				// trace('dead');
			}

			if (holdingObjectType != null)
			{
				if (FlxG.mouse.justMoved)
				{
					var mousePos:FlxPoint = FlxG.mouse.getScreenPosition(camHUD);
					switch (holdingObjectType)
					{
						case 'combo':
							comboOffset[4] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							comboOffset[5] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
						case 'rating':
							comboOffset[0] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							comboOffset[1] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
						case 'numscore':
							comboOffset[2] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							comboOffset[3] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
					}
					repositionCombo();
				}
			}

			if (PlayerSettings.controls.is(RESET))
			{
				for (i in 0...comboOffset.length)
					comboOffset[i] = 0;
				repositionCombo();
			}
		}
		else
		{
			var noteOffset:Int = ClientPrefs.getPref('noteOffset');
			if (PlayerSettings.controls.is(UI_LEFT, JUST_PRESSED))
			{
				barPercent = Math.max(delayMin, Math.min(noteOffset - 1, delayMax));
				updateNoteDelay();
			}
			else if (PlayerSettings.controls.is(UI_RIGHT, JUST_PRESSED))
			{
				barPercent = Math.max(delayMin, Math.min(noteOffset + 1, delayMax));
				updateNoteDelay();
			}

			var mult:Int = 1;
			if (PlayerSettings.controls.is(UI_LEFT, PRESSED) || PlayerSettings.controls.is(UI_RIGHT, PRESSED))
			{
				holdTime += elapsed;
				if (PlayerSettings.controls.is(UI_LEFT, PRESSED))
					mult = -1;
			}

			if (PlayerSettings.controls.is(UI_LEFT, JUST_RELEASED) || PlayerSettings.controls.is(UI_RIGHT, JUST_RELEASED))
				holdTime = 0;

			if (holdTime > .5)
			{
				barPercent += 100 * elapsed * mult;
				barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				updateNoteDelay();
			}

			if (PlayerSettings.controls.is(RESET))
			{
				holdTime = 0;
				barPercent = 0;
				updateNoteDelay();
			}
		}

		if (PlayerSettings.controls.is(ACCEPT))
		{
			onComboMenu = !onComboMenu;
			updateMode();
		}

		if (PlayerSettings.controls.is(BACK))
		{
			zoomTween?.cancel();
			beatTween?.cancel();

			zoomTween = null;
			beatTween = null;

			persistentUpdate = false;

			CustomFadeTransition.nextCamera = camOther;
			MusicBeatState.switchState(new OptionsState());

			TitleState.playTitleMusic();
			FlxG.mouse.visible = false;
		}

		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
	}

	var zoomTween:FlxTween;
	var lastBeatHit:Int = -1;

	override public function beatHit()
	{
		super.beatHit();

		if (lastBeatHit == curBeat)
		{
			return;
		}

		if (curBeat % 2 == 0)
		{
			boyfriend.dance();
			gf.dance();
		}

		if (curBeat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			zoomTween?.cancel();
			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1, {
				ease: FlxEase.circOut,
				onComplete: function(twn:FlxTween)
				{
					zoomTween = null;
				}
			});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;

			beatTween?.cancel();
			beatTween = FlxTween.tween(beatText, {alpha: 0}, 1, {
				ease: FlxEase.sineIn,
				onComplete: function(twn:FlxTween)
				{
					beatTween = null;
				}
			});
		}

		lastBeatHit = curBeat;
	}

	private function repositionCombo()
	{
		var comboOffset:Array<Int> = ClientPrefs.getPref('comboOffset');
		combo.screenCenter();

		combo.x = coolText.x - 40 + comboOffset[4];
		combo.y -= comboOffset[5];

		rating.screenCenter();

		rating.x = coolText.x - 40 + comboOffset[0];
		rating.y -= 60 + comboOffset[1];

		comboNums.screenCenter();

		comboNums.x = coolText.x - 90 + comboOffset[2];
		comboNums.y += 80 - comboOffset[3];

		reloadTexts();
	}

	private function createTexts()
	{
		for (i in 0...6)
		{
			var text:FlxText = new FlxText(10, 48 + (i * 30), 0, '', 24);
			text.setFormat(Paths.font("comic.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

			text.scrollFactor.set();
			text.borderSize = 2;

			dumbTexts.add(text);
			text.cameras = [camHUD];

			switch (i)
			{
				case 2 | 3:
					text.y += 24;
				case 4 | 5:
					text.y += 48;
			}
		}
	}

	private function reloadTexts()
	{
		var comboOffset:Array<Int> = ClientPrefs.getPref('comboOffset');
		for (i in 0...dumbTexts.length)
		{
			switch (i)
			{
				case 0:
					dumbTexts.members[i].text = 'Combo Offset:';
				case 1:
					dumbTexts.members[i].text = '[' + comboOffset[4] + ', ' + comboOffset[5] + ']';

				case 2:
					dumbTexts.members[i].text = 'Rating Offset:';
				case 3:
					dumbTexts.members[i].text = '[' + comboOffset[0] + ', ' + comboOffset[1] + ']';

				case 4:
					dumbTexts.members[i].text = 'Numbers Offset:';
				case 5:
					dumbTexts.members[i].text = '[' + comboOffset[2] + ', ' + comboOffset[3] + ']';
			}
		}
	}

	private function updateNoteDelay()
	{
		var percent:Int = Math.round(barPercent);

		ClientPrefs.prefs.set('noteOffset', percent);
		timeTxt.text = 'Current offset: $percent ms';
	}

	private function updateMode()
	{
		combo.visible = onComboMenu;
		rating.visible = onComboMenu;

		comboNums.visible = onComboMenu;
		dumbTexts.visible = onComboMenu;

		timeBarBG.visible = !onComboMenu;
		timeBar.visible = !onComboMenu;
		timeTxt.visible = !onComboMenu;

		beatText.visible = !onComboMenu;
		changeModeText.text = '< ' + (onComboMenu ? 'COMBO OFFSET' : 'NOTE / BEAT DELAY') + ' (PRESS ACCEPT TO SWITCH) >';

		FlxG.mouse.visible = onComboMenu;
	}
}
