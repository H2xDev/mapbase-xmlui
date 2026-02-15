IncludeScript("xmlui/xml");

local DefinedPanels = {};
local ElementMappings = {};

local CUBIC_BEZIER_REGEX = regexp("cubic-bezier\\((?:\\s+)?([\\d\\.\\-]+)(?:\\s+)?,(?:\\s+)?([\\d\\.\\-]+)(?:\\s+)?,(?:\\s+)?([\\d\\.\\-]+)(?:\\s+)?,(?:\\s+)?([\\d\\.\\-]+)(?:\\s+)?\\)")

const REF_WIDTH = 640;
const REF_HEIGHT = 480;

::XMLUI <- {
	Mappings = {
		panel = "Panel"
		label = "Label"
		button = "Button"
		tween = "Panel"
		root = "Panel"
		script = "Panel"
	}

	PropPriority = [
		"font",
		"text",
		"fgColor",
		"bgColor",
		"width",
		"height",
		"x",
		"y", 
	],
}

function XMLUI::Open(filename) {
	local tree = XML.Open(filename);

	XML.LogWarning("XMLUI is in early development stage, expect some errors and crashes. Report them to the developer with steps to reproduce.");

	local rootPanel = ComposePanels(tree)
}

function XMLUI::SafeGet(table, key, d = null) {
	if (key in table) {
		return table[key];
	}

	return d;
}

function XMLUI::HEXToRGB(hexCode) {
    local h = hexCode.toupper();
    local r = 0, g = 0, b = 0, a = 255;

    switch (hexCode.len()) {
      // #rrggbb
      case 7:
      case 9:
        r = h.slice(1, 3).tointeger(16);
        g = h.slice(3, 5).tointeger(16);
        b = h.slice(5, 7).tointeger(16);

        if (hexCode.len() == 9) {
          a = h.slice(7, 9).tointeger(16);
        }
      break;

      // #rgb
      case 4:
      case 5:
        r = h.slice(1, 2);
        r += r;
        r = r.tointeger(16);

        g = h.slice(2, 3);
        g += g;
        g = g.tointeger(16);

        b = h.slice(3, 4);
        b += b;
        b = b.tointeger(16);

        // #rgba
        if (hexCode.len() == 5) {
          a = h.slice(4, 5);
          a += a;
          a = a.tointeger(16);
        }
      break;
    }


    return [r, g, b, a];
}

function XMLUI::GetPanelProperty(panel, prop) {
	local isRoot = panel == vgui.GetRootPanel();

	switch (prop) {
		case "x": return !isRoot ? panel.GetXPos() : 0;
		case "y": return !isRoot ? panel.GetYPos() : 0;

		case "width": return !isRoot ? panel.GetWide() : XRES(REF_WIDTH);
		case "height": return !isRoot ? panel.GetTall() : YRES(REF_HEIGHT);
	}

	return null;
}

function XMLUI::GetBaseValue(panel, prop) {
	switch (prop) {
		case "x":
		case "width": return panel.GetParent() ? panel.GetParent().GetWide() : XRES(REF_WIDTH);

		case "y":
		case "height": return panel.GetParent() ? panel.GetParent().GetTall() : YRES(REF_HEIGHT);

		case "marginRight":
		case "marginLeft": return panel.GetWide();

		case "marginTop":
		case "marginBottom": return panel.GetTall();
	}

	return null;
}

function XMLUI::ParseNumber(value, baseValue = null) {
	if (value == null && baseValue) return 0.0;
	if (value == null) return 0.0;

	if (typeof value == "string" && value.slice(-1) == "%") {
		value = XML.Replace(value, "%", "").tofloat() / 100.0;
		return baseValue * value;
	}

	return value.tofloat();
}

function XMLUI::SetPanelProperty(panel, prop, value) {
	local element = ElementMappings[panel.GetName()];
	local props = element ? element.props : {};

	element.props[prop] = value;

	switch (prop) {
		case "x":
		case "y": {
			value = ParseNumber(value, GetBaseValue(panel, prop));
			local marginA = prop == "x" 
				? SafeGet(element.props, "marginLeft", 0) 
				: SafeGet(element.props, "marginTop", 0);

			local marginB = prop == "x" 
				? SafeGet(element.props, "marginRight", 0) 
				: SafeGet(element.props, "marginBottom", 0);

			local marginValue = prop == "x"
				? ParseNumber(marginA, panel.GetWide()) - ParseNumber(marginB, panel.GetWide())
				: ParseNumber(marginA, panel.GetTall()) - ParseNumber(marginB, panel.GetTall());

			value += marginValue;

			local x = prop == "x" ? value : panel.GetXPos();
			local y = prop == "y" ? value : panel.GetYPos();

			panel.SetPos(x, y);
		} break;

		case "width":
		case "height": {
			value = ParseNumber(value, GetBaseValue(panel, prop));
			local width = prop == "width" ? value : panel.GetWide();
			local height = prop == "height" ? value : panel.GetTall();
			panel.SetSize(width, height);
		} break;

		case "text": {
			if ("SetText" in panel == false) break;
			panel.SetText(value);
			panel.SizeToContents();
		} break;

		case "fgColor": {
			if ("SetFgColor" in panel == false) break;
			local color = HEXToRGB(value);
			panel.SetFgColor(color[0], color[1], color[2], color[3]);
		} break;

		case "bgColor": {
			if ("SetBgColor" in panel == false) break;
			local color = HEXToRGB(value);
			panel.SetBgColor(color[0], color[1], color[2], color[3]);
		} break;

		case "font": {
			if ("SetFont" in panel == false) break;
			local fontIdx = surface.GetFont(value, true, "Tracker");
			panel.SetFont(fontIdx);
			panel.SizeToContents();
		} break;
	}
}

// CSS-like cubic-bezier function implementation
// Based on https://github.com/gre/bezier-easing
// MIT License
// rawString - cubic-bezier(x1, y1, x2, y2)
function XMLUI::GetBezierFunction(rawString) {
	local paramsCaptures = CUBIC_BEZIER_REGEX.capture(rawString);

	if (!paramsCaptures) {
		printl("Invalid cubic-bezier parameters: " + rawString);
		return function(x) { 
			printl("Invalid cubic-bezier parameters: " + rawString);
			return x; 
		}
	}

	local mX1 = rawString.slice(paramsCaptures[1].begin, paramsCaptures[1].end).tofloat();
	local mY1 = rawString.slice(paramsCaptures[2].begin, paramsCaptures[2].end).tofloat();
	local mX2 = rawString.slice(paramsCaptures[3].begin, paramsCaptures[3].end).tofloat();
	local mY2 = rawString.slice(paramsCaptures[4].begin, paramsCaptures[4].end).tofloat();

	if (mX1 == mY1 && mX2 == mY2) {
		return function(x) { return x; }
	}

	local kSplineTableSize = 11;
	local kSampleStepSize = 1.0 / (kSplineTableSize - 1.0);
	local sampleValues = array(kSplineTableSize);

	local CalcBezier = function(t, aA1, aA2) {
		return (( (1.0 - 3.0 * aA2 + 3.0 * aA1) * t + (3.0 * aA2 - 6.0 * aA1) ) * t + (3.0 * aA1)) * t;
	}

	local GetSlope = function(t, aA1, aA2) {
		return 3.0 * (1.0 - 3.0 * aA2 + 3.0 * aA1) * t * t + 2.0 * (3.0 * aA2 - 6.0 * aA1) * t + (3.0 * aA1);
	}

	for (local i = 0; i < kSplineTableSize; ++i) {
		sampleValues[i] = CalcBezier(i * kSampleStepSize, mX1, mX2);
	}

	local GetTForX = function(aX) {
		local intervalStart = 0.0;
		local currentSample = 1;
		local lastSample = kSplineTableSize - 1;

		for (; currentSample != lastSample && sampleValues[currentSample] <= aX; ++currentSample) {
			intervalStart += kSampleStepSize;
		}
		--currentSample;

		// Interpolate to provide an initial guess for t
		local dist = (aX - sampleValues[currentSample]) / (sampleValues[currentSample+1] - sampleValues[currentSample]);
		local guessForT = intervalStart + dist * kSampleStepSize;

		local initialSlope = GetSlope(guessForT, mX1, mX2);

		if (initialSlope >= 0.001) {
			for (local i = 0; i < 4; ++i) {
				local currentSlope = GetSlope(guessForT, mX1, mX2);
				if (currentSlope == 0.0) return guessForT;
				local currentX = CalcBezier(guessForT, mX1, mX2) - aX;
				guessForT -= currentX / currentSlope;
			}
			return guessForT;
		} else if (initialSlope == 0.0) {
			return guessForT;
		} else {
			local aA = intervalStart;
			local aB = intervalStart + kSampleStepSize;
			local currentX = 100.0;
			local currentT = 0;
			local i = 0;
			while (abs(currentX) > 0.0000001 && i < 10) {
				currentT = aA + (aB - aA) / 2.0;
				currentX = CalcBezier(currentT, mX1, mX2) - aX;
				if (currentX > 0.0) aB = currentT;
				else aA = currentT;
				++i;
			}
			return currentT;
		}
	}

	return function(x) {
		if (x == 0) return 0;
		if (x == 1) return 1;
		return CalcBezier(GetTForX(x), mY1, mY2);
	}
}

function XMLUI::EaseValue(progress, easing = "linear") {
	if (typeof easing == "function") {
		return easing(progress);
	}

	switch (easing) {
		case "linear": return progress;
		case "ease-in": return progress * progress;
		case "ease-out": return progress * (2 - progress);
		case "ease-in-out": return progress < 0.5 ? 2 * progress * progress : -1 + (4 - 2 * progress) * progress;
	}

	return progress;
}

function XMLUI::IsTweenValid(xmlElement) {
	if (xmlElement == null) return false;

	if (xmlElement.type != "tween") return false;

	local props = xmlElement.props;

	if ("played" in xmlElement.metadata) {
		return false;
	}

	if ("duration" in props == false) {
		LogError("Tween panel missing duration property");
		return false;
	}

	if ("prop" in props == false) {
		LogError("Tween panel missing prop property");
		return false;
	}

	return true;
}

function XMLUI::GetPanelChildren(panel) {
	local children = [];
	panel.GetChildren(children);
	return children;
}

function XMLUI::PlayTween(panel, targetPanel) {
	local tweenXMLElement = GetPanelXMLElement(panel);
	local targetXMLElement = GetPanelXMLElement(targetPanel);
	if (!IsTweenValid(tweenXMLElement)) return;

	tweenXMLElement.metadata.played <- true;

	local duration = tweenXMLElement.props.duration.tofloat() / 1000.0;
	local delay = SafeGet(tweenXMLElement.props, "delay", 0.0).tofloat() / 1000.0;

	local propToTween = tweenXMLElement.props.prop;
	local tweenValue = tweenXMLElement.props.to;

	local isPercentageValue = typeof tweenValue == "string" && tweenValue.slice(-1) == "%";
	local startPropValue = propToTween in targetXMLElement.props
		? ParseNumber(targetXMLElement.props[propToTween], GetBaseValue(targetPanel, propToTween))
		: 0.0;

	local ease = SafeGet(tweenXMLElement.props, "ease", "linear");

	if (startswith(ease, "cubic-bezier")) {
		ease = GetBezierFunction(ease);
	}

	local elapsed = 0.0;
	panel.SetCallback("OnTick", function() {
		if (delay > 0) {
			delay -= FrameTime();
			return;
		}

		local timeProgress = min(elapsed / duration, 1.0);
		local progress = EaseValue(timeProgress, ease);

		local endPropValue = ParseNumber(tweenValue, GetBaseValue(targetPanel, propToTween));
		local currentValue = startPropValue + (endPropValue - startPropValue) * progress;

		if (isPercentageValue) {
			local baseValue = GetBaseValue(targetPanel, propToTween);

			currentValue = baseValue
				? (currentValue / baseValue * 100.0).tofloat() + "%" 
				: startPropValue;
		}

		targetXMLElement.props[propToTween] <- currentValue;

		if (timeProgress >= 1.0) {
			// NOTE: Reparent tween children to the target panel
			// It will play automeatically on PerformLayout
			foreach (child in GetPanelChildren(panel)) child.SetParent(targetPanel);

			panel.RemoveTickSignal();
			panel.Destroy();
		}

		PerformLayout(targetPanel);

		elapsed += FrameTime();
	}.bindenv(this));

	panel.AddTickSignal(0.016);
}

function XMLUI::ExecuteScript(xmlElement) {
	if (xmlElement == null) return;
	if ("executed" in xmlElement.metadata) return;
	xmlElement.metadata.executed <- true;

	local scriptContent = xmlElement.innerText;

	if (scriptContent.len() == 0) return;

	local func = compilestring(scriptContent);

	if (!func) {
		LogError("Error loading script: " + err);
		return;
	}

	func.bindenv(xmlElement.parent)();
}

function XMLUI::PerformLayout(panel) {
	local xmlElement = GetPanelXMLElement(panel);
	if (xmlElement == null) return;

	ApplyPropsToPanel(panel, xmlElement);

	switch (xmlElement.type) {
		case "tween": 
			return PlayTween(panel, panel.GetParent());
		
		case "script":
			return ExecuteScript(xmlElement);

		default: {
			foreach (childPanel in GetPanelChildren(panel)) PerformLayout(childPanel);
		} break;
	}
}

function XMLUI::ComposePanels(xmlElement, parentPanel = null) {
	if (xmlElement.type in Mappings == false) {
		LogError("Unknown xmlElementtype: " + xmlElement.type);
		return;
	}

	if (!parentPanel) {
		parentPanel = vgui.GetRootPanel();
	}

	local isRoot = parentPanel == vgui.GetRootPanel();
	local name = SafeGet(xmlElement.props, "name", xmlElement.type);
	local panel = vgui.CreatePanel(Mappings[xmlElement.type], parentPanel, UniqueString("xml_panel_" + name));

	panel.SetSize(0, 0);
	panel.SetVisible(true);

	xmlElement.metadata.panelId <- panel.GetName();

	DefinedPanels[xmlElement.metadata.panelId] <- panel;
	ElementMappings[xmlElement.metadata.panelId] <- xmlElement;

	foreach (xmlChild in xmlElement.children) {
		ComposePanels(xmlChild, panel);
	}

	if ("SetCallback" in panel == false) return;

	local self = this;

	if (isRoot) {
		panel.SetCallback("PerformLayout", function() {
			if (isRoot) panel.SetSize(XRES(REF_WIDTH), YRES(REF_HEIGHT));

			self.PerformLayout(panel);
		});

		panel.MakeReadyForUse();
	}

	return panel;
}

function XMLUI::LogError(...) {
	local message = "";

	foreach (part in vargv) {
		message += part + " ";
	}

	if (message.len() > 0) {
		error("XMLUI Error: " + message + "\n");
	}
}

function XMLUI::ApplyPropsToPanel(panel, element) {
	foreach (key, value in element.props) {
		SetPanelProperty(panel, key, value);
	}
}

function XMLUI::GetPanelXMLElement(panel) {
	if (panel == null) return null;

	if (panel.GetName() in ElementMappings) {
		return ElementMappings[panel.GetName()];
	}

	return null;
}
