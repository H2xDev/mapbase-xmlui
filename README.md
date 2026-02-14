# Mapbase XMLUI

Zero-dependency XML-based VGUI wrapper for Mapbase for creating complex UI elements with ease. Partially inspired by web development.

## How to use

1. Create a folder in `scripts/vscripts` called `xmlui` and place files from this repository there.

2. In `mapspawn.nut` include xml_ui.nut
```nut
if (CLIENT_DLL) {
	IncludeScript("xmlui/xml_ui");
}
```

3. Create a file in `vscript_io/example.xml`
```xml
<!-- example.xml -->
<panel x="0" y="50%" width="0" height="100" bgColor="#000" marginTop="-50%">
	<label text="Sample text" x="0%" y="50%" fgColor="#fff" marginTop="-50%" marginLeft="-50%" font="ComputerUi">
		<tween prop="x" to="50%" duration="3000" ease="cubic-bezier(0,.22,0,1)" />
	</label>

	<tween prop="width" to="100%" duration="1000" delay="500" ease="cubic-bezier(0,.22,0,1)">
		<tween prop="y" to="100%" duration="1000" ease="cubic-bezier(1,0,0,1)"></tween>
		<tween prop="marginTop" to="-100%" duration="1000" ease="cubic-bezier(1,0,0,1)"></tween>
	</tween>
</panel>
```

4. In `mapspawn.nut` load the XML file
```nut
if (CLIENT_DLL) {
    XMLUI.Open("example.xml");
}
```

## Supported elements
|element name|description|
|---|---|
|`<panel>`|Default element. Can be used as a container for other elements.|
|`<label>`|A label element for displaying text.|
|`<tween>`|A tween element for animating properties of its parent element. Must be a child of another element which should be animated. Can also be a child of another tween element for chaining animations.|

## Supported attributes

### General attributes
|attribute name|description|
|---|---|
|`name`|The name of the element. Mostly used for debug.|
|`x`|The x position of the element. Can be in pixels or percentage.|
|`y`|The y position of the element. Can be in pixels or percentage.|
|`width`|The width of the element. Can be in pixels or percentage.|
|`height`|The height of the element. Can be in pixels or percentage.|
|`bgColor`|The background color of the element. Can be in hex format.|
|`fgColor`|The foreground color of the element. Can be in hex format.|
|`marginTop`|The top margin of the element. Can be in pixels or percentage (percentage is relative to the height of the element).|
|`marginLeft`|The left margin of the element. Can be in pixels or percentage (percentage is relative to the width of the element).|
|`marginBottom`|The bottom margin of the element. Can be in pixels or percentage (percentage is relative to the height of the element).|
|`marginRight`|The right margin of the element. Can be in pixels or percentage (percentage is relative to the width of the element).|


### Label attributes
|attribute name|description|
|---|---|
|`text`|The text of the label element.|
|`font`|The font of the label element.|

### Tween attributes
|attribute name|description|
|---|---|
|`prop`|The property to animate. Can be any of the general attributes or `text` for label elements.|
|`to`|The value to animate to. Can be in pixels or percentage for position and size properties, hex format for color properties, and string for text property.|
|`duration`|The duration of the animation in milliseconds.|
|`delay`|The delay before the animation starts in milliseconds.|
|`ease`|The easing function of the animation. Can be `linear`, `ease-in`, `ease-out`, `ease-in-out`, or a custom cubic-bezier function in the format `cubic-bezier(x1,y1,x2,y2)`.|


## Contributing
Contributions are welcome! If you have any ideas for new features or improvements, feel free to open an issue or a pull request.
