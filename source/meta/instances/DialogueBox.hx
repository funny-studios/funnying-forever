package meta.instances;

import flixel.math.FlxMath;
import flixel.animation.FlxAnimation;
import meta.data.ClientPrefs;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.utils.Assets;

using StringTools;

typedef DialogueCharacterFile =
{
	var image:String;
	var dialogue_pos:String;
	var no_antialiasing:Bool;

	var animations:Array<DialogueAnimArray>;
	var position:Array<Float>;
	var scale:Float;
}

typedef DialogueAnimArray =
{
	var anim:String;
	var loop_name:String;
	var loop_offsets:Array<Int>;
	var idle_name:String;
	var idle_offsets:Array<Int>;
}

// Gonna try to kind of make it compatible to Forever Engine,
// love u Shubs no homo :flushedh4:
typedef DialogueFile =
{
	var dialogue:Array<DialogueLine>;
}

typedef DialogueLine =
{
	var portrait:Null<String>;
	var expression:Null<String>;
	var text:Null<String>;
	var boxState:Null<String>;
	var speed:Null<Float>;
	var sound:Null<String>;
}

class DialogueCharacter extends FlxSprite
{
	private inline static final IDLE_SUFFIX:String = '-IDLE';

	public inline static final DEFAULT_CHARACTER:String = 'bf';
	public inline static final DEFAULT_SCALE:Float = .7;

	public var jsonFile:DialogueCharacterFile = null;
	public var dialogueAnimations:Map<String, DialogueAnimArray> = new Map();

	public var startingPos:Float = 0; // For center characters, it works as the starting Y, for everything else it works as starting X
	public var isGhost:Bool = false; // For the editor
	public var curCharacter:String = 'bf';
	public var skiptimer = 0;
	public var skipping = 0;

	public function new(x:Float = 0, y:Float = 0, character:String = null)
	{
		super(x, y);

		if (character == null)
			character = DEFAULT_CHARACTER;
		this.curCharacter = character;

		reloadCharacterJson(character);
		frames = Paths.getSparrowAtlas('dialogue/' + jsonFile.image);
		reloadAnimations();

		antialiasing = ClientPrefs.getPref('globalAntialiasing');
		if (jsonFile.no_antialiasing == true)
			antialiasing = false;
	}

	public function reloadCharacterJson(character:String)
	{
		var characterPath:String = 'images/dialogue/' + character + '.json';
		var rawJson = null;

		var path:String = Paths.getPreloadPath(characterPath);

		rawJson = Assets.getText(path);
		jsonFile = cast Json.parse(rawJson);
	}

	public function reloadAnimations()
	{
		dialogueAnimations.clear();
		if (jsonFile.animations != null && jsonFile.animations.length > 0)
		{
			for (anim in jsonFile.animations)
			{
				animation.addByPrefix(anim.anim, anim.loop_name, 24, isGhost);
				animation.addByPrefix(anim.anim + IDLE_SUFFIX, anim.idle_name, 24, true);
				dialogueAnimations.set(anim.anim, anim);
			}
		}
	}

	public function playAnim(animName:String = null, playIdle:Bool = false)
	{
		var leAnim:String = animName;
		if (animName == null || !dialogueAnimations.exists(animName))
		{
			// Anim is null, get a random animation
			var arrayAnims:Array<String> = [];
			for (anim in dialogueAnimations)
			{
				arrayAnims.push(anim.anim);
			}
			if (arrayAnims.length > 0)
			{
				leAnim = arrayAnims[FlxG.random.int(0, arrayAnims.length - 1)];
			}
		}

		if (dialogueAnimations.exists(leAnim)
			&& (dialogueAnimations.get(leAnim).loop_name == null
				|| dialogueAnimations.get(leAnim).loop_name.length < 1
				|| dialogueAnimations.get(leAnim).loop_name == dialogueAnimations.get(leAnim).idle_name))
		{
			playIdle = true;
		}
		animation.play(playIdle ? leAnim + IDLE_SUFFIX : leAnim, false);

		if (dialogueAnimations.exists(leAnim))
		{
			var anim:DialogueAnimArray = dialogueAnimations.get(leAnim);
			if (playIdle)
			{
				offset.set(anim.idle_offsets[0], anim.idle_offsets[1]);
				// trace('Setting idle offsets: ' + anim.idle_offsets);
			}
			else
			{
				offset.set(anim.loop_offsets[0], anim.loop_offsets[1]);
				// trace('Setting loop offsets: ' + anim.loop_offsets);
			}
		}
		else
		{
			offset.set(0, 0);
			trace('Offsets not found! Dialogue character is badly formatted, anim: '
				+ leAnim
				+ ', '
				+ (playIdle ? 'idle anim' : 'loop anim'));
		}
	}

	public function animationIsLoop():Bool
	{
		if (animation.curAnim == null)
			return false;
		return !animation.curAnim.name.endsWith(IDLE_SUFFIX);
	}
}

class DialogueBox extends FlxSpriteGroup
{
	private var dialogueList:DialogueFile = null;

	public var finishThing:Void->Void;
	public var nextDialogueThing:Void->Void = null;
	public var skipDialogueThing:Void->Void = null;

	private var bgFade:FlxSprite = null;
	private var box:FlxSprite;

	private var arrayCharacters:Array<DialogueCharacter> = [];

	private var currentText:Int = 0;
	private var offsetPos:Float = -600;

	private var textBoxTypes:Array<String> = ['normal', 'angry'];

	public var closeSound:String = 'dialogueClose';
	public var closeVolume:Float = 1;

	private var dialogueEnded:Bool = false;

	public static var LEFT_CHAR_X:Float = -60;
	public static var RIGHT_CHAR_X:Float = -100;
	public static var DEFAULT_CHAR_Y:Float = 60;

	public static var DEFAULT_TEXT_X = 175;
	public static var DEFAULT_TEXT_Y = 432;

	public static var LONG_TEXT_ADD = 24;

	private var scrollSpeed = 4000;
	private var daText:TypedAlphabet = null;

	private var lastCharacter:Int = -1;
	private var lastBoxType:String = '';

	public function new(dialogueList:DialogueFile, ?song:String = null)
	{
		super();

		if (song != null && song != '')
		{
			FlxG.sound.playMusic(Paths.music(song), 0);
			FlxG.sound.music?.fadeIn(2, 0, 1);
		}

		bgFade = new FlxSprite(-500, -500).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE);
		bgFade.scrollFactor.set();

		bgFade.visible = true;
		bgFade.alpha = 0;

		add(bgFade);

		this.dialogueList = dialogueList;
		spawnCharacters();

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');

		box.scrollFactor.set();
		box.antialiasing = ClientPrefs.getPref('globalAntialiasing');

		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('normalOpen', 'Speech Bubble Normal Open', 24, false);

		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('angryOpen', 'speech bubble loud open', 24, false);

		box.animation.addByPrefix('center-normal', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-normalOpen', 'Speech Bubble Middle Open', 24, false);

		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.addByPrefix('center-angryOpen', 'speech bubble Middle loud open', 24, false);

		box.animation.play('normal', true);
		box.visible = false;

		box.setGraphicSize(Std.int(box.width * .9));
		box.updateHitbox();

		daText = new TypedAlphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, '');

		daText.scaleX = .7;
		daText.scaleY = .7;

		add(box);
		add(daText);

		startNextDialog();
	}

	private inline function spawnCharacters()
	{
		var charsMap:Map<String, Bool> = new Map();
		for (i in 0...dialogueList.dialogue.length)
		{
			if (dialogueList.dialogue[i] != null)
			{
				var charToAdd:String = dialogueList.dialogue[i].portrait;
				if (!charsMap.exists(charToAdd) || !charsMap.get(charToAdd))
				{
					charsMap.set(charToAdd, true);
				}
			}
		}

		for (individualChar in charsMap.keys())
		{
			var x:Float = LEFT_CHAR_X;
			var y:Float = DEFAULT_CHAR_Y;
			var char:DialogueCharacter = new DialogueCharacter(x + offsetPos, y, individualChar);

			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * char.jsonFile.scale));
			char.updateHitbox();

			char.scrollFactor.set();
			char.alpha = 0;

			add(char);

			var saveY:Bool = false;
			switch (char.jsonFile.dialogue_pos)
			{
				case 'center':
					{
						char.x = FlxG.width / 2;
						char.x -= char.width / 2;

						y = char.y;

						char.y = FlxG.height + 50;
						saveY = true;
					}
				case 'right':
					{
						x = FlxG.width - char.width + RIGHT_CHAR_X;
						char.x = x - offsetPos;
					}
			}

			x += char.jsonFile.position[0];
			y += char.jsonFile.position[1];

			char.x += char.jsonFile.position[0];
			char.y += char.jsonFile.position[1];

			char.startingPos = (saveY ? y : x);
			arrayCharacters.push(char);
		}
	}

	override function update(elapsed:Float)
	{
		if (!dialogueEnded)
		{
			bgFade.alpha += .5 * elapsed;
			if (bgFade.alpha > .5)
				bgFade.alpha = .5;

			if (PlayerSettings.controls.is(ACCEPT))
			{
				if (!daText.finishedText)
				{
					daText.finishText();
					if (skipDialogueThing != null)
					{
						skipDialogueThing();
					}
				}
				else if (currentText >= dialogueList.dialogue.length)
				{
					dialogueEnded = true;
					for (i in 0...textBoxTypes.length)
					{
						var checkArray:Array<String> = ['', 'center-'];
						var animName:String = box.animation.curAnim.name;
						for (j in 0...checkArray.length)
						{
							if (animName == checkArray[j] + textBoxTypes[i] || animName == checkArray[j] + textBoxTypes[i] + 'Open')
							{
								box.animation.play(checkArray[j] + textBoxTypes[i] + 'Open', true);
							}
						}
					}

					box.animation.curAnim.curFrame = box.animation.curAnim.frames.length - 1;
					box.animation.curAnim.reverse();

					if (daText != null)
					{
						daText.kill();
						remove(daText, true);

						daText.destroy();
						daText = null;
					}

					updateBoxOffsets(box);
					FlxG.sound.music?.fadeOut(1, 0);
				}
				else
				{
					startNextDialog();
				}
				FlxG.sound.play(Paths.sound(closeSound), closeVolume);
			}
			else if (daText.finishedText)
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if (char != null && char.animation.curAnim != null && char.animationIsLoop() && char.animation.finished)
				{
					char.playAnim(char.animation.curAnim.name, true);
				}
			}
			else
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if (char != null && char.animation.curAnim != null && char.animation.finished)
				{
					char.animation.curAnim.restart();
				}
			}

			if (box.animation.curAnim.finished)
			{
				for (i in 0...textBoxTypes.length)
				{
					var checkArray:Array<String> = ['', 'center-'];
					var animName:String = box.animation.curAnim.name;
					for (j in 0...checkArray.length)
					{
						if (animName == checkArray[j] + textBoxTypes[i] || animName == checkArray[j] + textBoxTypes[i] + 'Open')
						{
							box.animation.play(checkArray[j] + textBoxTypes[i], true);
						}
					}
				}
				updateBoxOffsets(box);
			}

			if (lastCharacter != -1 && arrayCharacters.length > 0)
			{
				for (i in 0...arrayCharacters.length)
				{
					var char = arrayCharacters[i];
					if (char != null)
					{
						if (i != lastCharacter)
						{
							switch (char.jsonFile.dialogue_pos)
							{
								case 'left':
									char.x -= scrollSpeed * elapsed;
									if (char.x < char.startingPos + offsetPos)
										char.x = char.startingPos + offsetPos;
								case 'center':
									char.y += scrollSpeed * elapsed;
									if (char.y > char.startingPos + FlxG.height)
										char.y = char.startingPos + FlxG.height;
								case 'right':
									char.x += scrollSpeed * elapsed;
									if (char.x > char.startingPos - offsetPos)
										char.x = char.startingPos - offsetPos;
							}
							char.alpha = Math.max(char.alpha + (3 * elapsed), 0);
						}
						else
						{
							switch (char.jsonFile.dialogue_pos)
							{
								case 'left':
									char.x += scrollSpeed * elapsed;
									if (char.x > char.startingPos)
										char.x = char.startingPos;
								case 'center':
									char.y -= scrollSpeed * elapsed;
									if (char.y < char.startingPos)
										char.y = char.startingPos;
								case 'right':
									char.x -= scrollSpeed * elapsed;
									if (char.x < char.startingPos)
										char.x = char.startingPos;
							}
							char.alpha = Math.min(char.alpha + (3 * elapsed), 1);
						}
					}
				}
			}
		}
		else
		{
			// Dialogue ending
			if (box != null && box.animation.curAnim.curFrame <= 0)
			{
				box.kill();
				remove(box, true);
				box.destroy();
				box = null;
			}

			if (bgFade != null)
			{
				bgFade.alpha -= .5 * elapsed;
				if (bgFade.alpha <= 0)
				{
					bgFade.kill();
					remove(bgFade, true);
					bgFade.destroy();
					bgFade = null;
				}
			}

			for (i in 0...arrayCharacters.length)
			{
				var leChar:DialogueCharacter = arrayCharacters[i];
				if (leChar != null)
				{
					switch (arrayCharacters[i].jsonFile.dialogue_pos)
					{
						case 'left':
							leChar.x -= scrollSpeed * elapsed;
						case 'center':
							leChar.y += scrollSpeed * elapsed;
						case 'right':
							leChar.x += scrollSpeed * elapsed;
					}
					leChar.alpha -= elapsed * 10;
				}
			}

			if (box == null && bgFade == null)
			{
				for (i in 0...arrayCharacters.length)
				{
					var leChar:DialogueCharacter = arrayCharacters[0];
					if (leChar != null)
					{
						arrayCharacters.remove(leChar);
						leChar.kill();
						remove(leChar, true);
						leChar.destroy();
					}
				}
				finishThing();
				kill();
			}
		}
		super.update(elapsed);
	}

	private inline function startNextDialog():Void
	{
		var curDialogue:DialogueLine = null;
		do
		{
			curDialogue = dialogueList.dialogue[currentText];
		}
		while (curDialogue == null);

		if (curDialogue.text == null || curDialogue.text.length < 1)
			curDialogue.text = ' ';
		if (curDialogue.boxState == null)
			curDialogue.boxState = 'normal';
		if (curDialogue.speed == null || Math.isNaN(curDialogue.speed))
			curDialogue.speed = .05;

		var animName:String = curDialogue.boxState;
		var boxType:String = textBoxTypes[0];
		for (i in 0...textBoxTypes.length)
		{
			if (textBoxTypes[i] == animName)
				boxType = animName;
		}

		var character:Int = 0;
		box.visible = true;
		for (i in 0...arrayCharacters.length)
		{
			if (arrayCharacters[i].curCharacter == curDialogue.portrait)
			{
				character = i;
				break;
			}
		}

		var lePosition:String = arrayCharacters[character].jsonFile.dialogue_pos;
		var centerPrefix:String = lePosition == 'center' ? 'center-' : '';

		if (character != lastCharacter)
		{
			box.animation.play(centerPrefix + boxType + 'Open', true);
			updateBoxOffsets(box);
			box.flipX = (lePosition == 'left');
		}
		else if (boxType != lastBoxType)
		{
			box.animation.play(centerPrefix + boxType, true);
			updateBoxOffsets(box);
		}

		lastCharacter = character;
		lastBoxType = boxType;

		daText.sound = curDialogue.sound;
		daText.text = curDialogue.text;

		if (daText.sound == null || daText.sound.trim().length <= 0)
			daText.sound = 'dialogue';

		daText.y = DEFAULT_TEXT_Y;
		if (daText.rows > 2)
			daText.y -= LONG_TEXT_ADD;

		var char:DialogueCharacter = arrayCharacters[character];
		if (char != null)
		{
			char.playAnim(curDialogue.expression, daText.finishedText);
			if (char.animation.curAnim != null)
				char.animation.curAnim.frameRate = FlxMath.bound(24 - (((curDialogue.speed - .05) / 5) * 480), 12, 48);
		}
		currentText++;
		if (nextDialogueThing != null)
			nextDialogueThing();
	}

	public inline static function parseDialogue(path:String):DialogueFile
		return cast Json.parse(Assets.getText(path));

	public inline static function updateBoxOffsets(box:FlxSprite)
	{
		// Had to make it static because of the editors
		box.centerOffsets();
		box.updateHitbox();

		box.offset.set(10, 0);

		var curAnim:FlxAnimation = box.animation.curAnim;
		if (curAnim != null)
		{
			var name:String = Paths.formatToSongPath(curAnim.name);
			if (name.startsWith('angry'))
			{
				box.offset.set(50, 65);
			}
			else if (name.startsWith('center-angry'))
			{
				box.offset.set(50, 30);
			}
		}
		if (!box.flipX)
			box.offset.y += 10;
	}
}
