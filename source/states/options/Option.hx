package states.options;

import meta.data.ClientPrefs;
import meta.instances.Alphabet;

using StringTools;

class Option
{
	public inline static final DEFAULT_VALUE:String = 'NULL_VARIABLE';

	private var child:Alphabet;

	public var text(get, set):String;
	public var onChange:Void->Void = null; // Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; // bool, int (or integer), float (or fl), percent, string (or str)

	// Bool will use checkboxes
	// Everything else will use a text
	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; // Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; // Variable from ClientPrefs.hx

	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; // Don't change this
	public var options:Array<String> = null; // Only used in string type

	public var changeValue:Dynamic = 1; // Only used in int/float/percent type, how much is changed when you PRESS

	public var minValue:Dynamic = null; // Only used in int/float/percent type
	public var maxValue:Dynamic = null; // Only used in int/float/percent type

	public var decimals:Int = 1; // Only used in float/percent type

	public var displayFormat:String = '%v'; // How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var description:String = '';
	public var name:String = 'Unknown';

	public function new(name:String, description:String = '', variable:String, type:String = 'bool', defaultValue:Dynamic = DEFAULT_VALUE,
			?options:Array<String> = null)
	{
		this.name = name;
		this.description = description;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if (defaultValue == DEFAULT_VALUE)
		{
			switch (type)
			{
				case 'bool':
					defaultValue = false;
				case 'int' | 'float':
					defaultValue = 0;
				case 'percent':
					defaultValue = 1;
				case 'string':
					defaultValue = '';
					if (options.length > 0)
						defaultValue = options[0];
			}
		}

		if (getValue() == null)
		{
			setValue(defaultValue);
		}

		switch (type)
		{
			case 'string':
				{
					var value:Dynamic = Paths.formatToSongPath(getValue());
					var num:Int = -1;

					for (i in 0...options.length)
					{
						if (Paths.formatToSongPath(options[i]) == value)
						{
							num = i;
							break;
						}
					}
					if (num > -1)
						curOption = num;
				}
			case 'percent':
				{
					displayFormat = '%v%';
					changeValue = .01;

					minValue = 0;
					maxValue = 1;

					scrollSpeed = .5;
					decimals = 2;
				}
		}
	}

	public function change()
	{
		// nothing lol
		if (onChange != null)
			onChange();
		ClientPrefs.saveSettings();
	}

	public function getValue():Dynamic
	{
		return ClientPrefs.getPref(variable);
	}

	public function setValue(value:Dynamic)
	{
		ClientPrefs.prefs.set(variable, value);
	}

	public function setChild(child:Alphabet)
	{
		this.child = child;
	}

	private function get_text()
	{
		if (child != null)
		{
			return child.text;
		}
		return null;
	}

	private function set_text(newValue:String = '')
	{
		if (child != null)
			child.text = newValue;
		return null;
	}

	private function get_type()
	{
		var newValue:String = 'bool';
		switch (type.trim().toLowerCase())
		{
			case 'int' | 'float' | 'percent' | 'string':
				newValue = type;
			case 'integer':
				newValue = 'int';
			case 'str':
				newValue = 'string';
			case 'fl':
				newValue = 'float';
		}
		type = newValue;
		return type;
	}
}
