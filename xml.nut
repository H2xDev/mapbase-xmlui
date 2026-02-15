::XML<- {
	version = "0.1.0"

	Errors = {
		OK = 0,
		UNEXPECTED_TAG_OPEN = 1,
		UNEXPECTED_TAG_CLOSE = 2,
	}

	ErrorMessages = {
		[0] = "OK",
		[1] = "Unexpected tag open",
		[2] = "Unexpected tag close",
	}
}

local TAG_OPEN_REGEX = regexp("<[\\w\\-]+(?:\\s+|\\n+)?(?:(?:[\\w\\d\\-]+=\".+\"(?:\\s+|\\n+)?)+)?\\/?>")
// local TAG_OPEN_REGEX = regexp("<[\w\-]+(?:\s+|\n+)(?:[\w\d\-]+=\".+\"(?:\s+|\n+)?)+/?>")
local TAG_NAME_REGEX = regexp("<([a-zA-Z0-9_]+)");
local TAG_PROPS_REGEX = regexp("(\\w+)=\"([^\"]+)\"");
local TAG_CLOSE_REGEX = regexp("</[\\w\\-]+>");
local COMMENT_REGEX = regexp("<!--(?:\\s+|\\n).+(?:\\s+|\\n)-->");

function XML::Open(filename) {
	local fileData = FileToString(filename) || "";
	return Parse(fileData);
}

function XML::CreateElement(type) {
	local element = {
		type = type,
		parent = null,
		children = [],
		props = {},
		metadata = {}
		innerText = "",
	}

	return element;
}

function XML::FindElementByType(element, type, deep = false) {
	foreach (child in element.children) {
		if (child.type == type) {
			return child;
		}

		if (deep) {
			local found = FindElementByType(child, type, true);

			if (found) {
				return found;
			}
		}
	}

	return null;
}

function XML::LogError(...) {
	local message = "";

	foreach (part in vargv) {
		message += part + " ";
	}

	if (message.len() > 0) {
		error("XML Warning: " + message + "\n");
	}
}

function XML::LogWarning(...) {
	local message = "";

	foreach (part in vargv) {
		message += part + " ";
	}

	if (message.len() > 0) {
		error("XML Warning: " + message + "\n");
	}
}

function XML::QuerySelector(element, selector) {
	local isClass = (selector.len() > 0 && selector.slice(0, 1) == ".");
	local isId = (selector.len() > 0 && selector.slice(0, 1) == "#");

	if (typeof selector != "string") {
		error("Selector must be a string");
		return null;
	}

	foreach (child in element.children) {
		local found = false;

		if (isClass) {
			if ("class" in child.props) {
				local classList = split(child.props["class"], " ");
				foreach (className in classList) {
					if (className == selector.slice(1)) {
						found = true;
						break;
					}
				}
			}
		} else if (isId) {
			if ("id" in child.props && child.props["id"] == selector.slice(1)) {
				found = true;
			}
		} else {
			// Tag name selector
			if (child.type == selector) {
				found = true;
			}
		}

		if (found) return child;
		
		// Search deeper
		local result = QuerySelector(child, selector);
		if (result) return result;
	}

	return null;
}

function XML::AddChild(parent, child) {
	child.parent = parent;
	parent.children.append(child);
}

function XML::Replace(source, what, by, replaceAll = false) {
	if (source.len() < what.len()) return source;
	
	local idx = source.find(what);
	if (idx == null) return source;

	if (!replaceAll) {
		return source.slice(0, idx) + by + source.slice(idx + what.len());
	}

	local result = "";
	local lastIdx = 0;

	while (idx != null) {
		result += source.slice(lastIdx, idx) + by;
		lastIdx = idx + what.len();
		idx = source.find(what, lastIdx);
	}

	result += source.slice(lastIdx);
	return result;
}

function XML::PushError(message) {
	Print("XMLerror: " + message);
}

function XML::ProcessTag(tagData, parent) {
	local captureData = TAG_NAME_REGEX.capture(tagData);

	local tagName = tagData.slice(captureData[1].begin, captureData[1].end);
	local element = CreateElement(tagName);

	if (parent) {
		AddChild(parent, element);
	}

	local lastCaptured = 0;
	local propsCapture = TAG_PROPS_REGEX.capture(tagData);

	while (propsCapture) {
		local propName = tagData.slice(propsCapture[1].begin, propsCapture[1].end);
		local propValue = tagData.slice(propsCapture[2].begin, propsCapture[2].end);

		element.props[propName] <- propValue;

		lastCaptured = propsCapture[0].end;
		propsCapture = TAG_PROPS_REGEX.capture(tagData, lastCaptured);
	}

	return element;
}

function XML::LogTable(table, indent = 0, processed = []) {
	local indentStr = "  ";

	for (local i = 0; i < indent; i++) {
		indentStr += "  ";
	}

	local superIndentStr = indentStr;

	printl(indentStr + "{");

	processed.push(table);

	indentStr += "  ";

	foreach (key, value in table) {
		if (typeof value == "table") {
			if (processed.find(value) != null) {
				printl(indentStr + key + ": { circular reference }");
				continue;
			}

			if (value.keys().len() == 0) {
				printl(indentStr + key + ": { empty }");
				continue;
			}

			print(indentStr + key + ": ");
			LogTable(value, indent + 1, processed);
		} else if (typeof value == "array") {
			if (value.len() == 0) {
				printl(indentStr + key + ": [ empty ]");
				continue;
			}
			printl(indentStr + key + ": [");
			for (local i = 0; i < value.len(); i++) {
				local item = value[i];
				if (typeof item == "table" || typeof item == "array") {
					LogTable(item, indent + 1, processed);
				} else {
					if (typeof item == "string") {
						item = "\"" + item + "\"";
					}
					printl(indentStr + "  " + item);
				}
			}
			printl(indentStr + "]");
		} else {
			if (typeof value == "string") {
				value = "\"" + value + "\"";
			}
			printl(indentStr + key + ": " + value);
		}
	}

	printl(superIndentStr + "}");
}

function XML::Parse(fileData) {
	local data = "";
	local currentTag = CreateElement("root");

	foreach (char in fileData) {
		char = format("%c", char);

		data += char;

		if (char == ">") {
			local commentCapture = COMMENT_REGEX.capture(data);
			local tagCapture = TAG_OPEN_REGEX.capture(data);
			local tagCloseCapture = TAG_CLOSE_REGEX.capture(data);

			local isCaptured = commentCapture || tagCapture || tagCloseCapture;

			if (commentCapture) {
				// Comment, ignore content
				printl("Comment found: " + data.slice(commentCapture[0].begin, commentCapture[0].end));
			} else if (tagCapture) {
				printl("Tag found: " + data.slice(tagCapture[0].begin, tagCapture[0].end));
				local tagStr = data.slice(tagCapture[0].begin, tagCapture[0].end);
				local rawText = data.slice(0, tagCapture[0].begin);

				currentTag.innerText += rawText;
				currentTag = ProcessTag(tagStr, currentTag);

				local isSelfClosing = endswith(tagStr, "/>");
				if (isSelfClosing && currentTag.parent) {
					currentTag = currentTag.parent;
				}
			} else if (tagCloseCapture) {
				local tagStr = data.slice(tagCloseCapture[0].begin, tagCloseCapture[0].end);
				currentTag.innerText += data.slice(0, tagCloseCapture[0].begin);
				currentTag.innerText = strip(currentTag.innerText);
				printl("Closing tag found: " + tagStr);

				if (currentTag.parent) {
					currentTag = currentTag.parent;
				} else {
					LogWarning("Unexpected closing tag without parent: " + data.slice(tagCloseCapture[0].begin, tagCloseCapture[0].end));
				}
			}

			data = isCaptured ? "" : data;
		}
	}

	return currentTag;
}

// function XML::Parse(fileData) {
// 	// Remove newlines to simplify parsing structure
// 	fileData = Replace(fileData, "\n", "", true);
// 	fileData = Replace(fileData, "\r", "", true);
// 	fileData = Replace(fileData, "\t", "", true);
// 
// 	local rootElement = CreateElement("root");
// 
// 	local isInComment = false;
// 	local isTagOpen = false;
// 
// 	local isOpenTag = false;
// 	local isCloseTag = false;
// 
// 	local currentTag = rootElement;
// 	local tagData = "";
// 	
// 	// Pre-calculate length for loop
// 	local len = fileData.len();
// 
// 	for (local i = 0; i < len; i++) {
// 		local char = fileData[i]; // get integer code
// 		local charStr = format("%c", char); // convert to string
// 
// 		if (isInComment) {
// 			if (tagData.len() > 2 && tagData.slice(-2) == "--" && charStr == ">") {
// 				isInComment = false;
// 				// printl("Comment: " + tagData + ">");
// 				tagData = "";
// 			} else {
// 				tagData += charStr;
// 			}
// 			continue;
// 		}
// 
// 		if (charStr == "<") {
// 			if (isTagOpen) {
// 				// return Errors.UNEXPECTED_TAG_OPEN;
// 				// Instead of erroring, reset and assume previous was malformed text
// 				isTagOpen = false;
// 				tagData = "";
// 			}
// 			
// 			// Check for comment start
// 			if (i + 3 < len && fileData.slice(i, i + 4) == "<!--") {
// 				isInComment = true;
// 				tagData = "<!--";
// 				i += 3; // Skip "!--"
// 				continue;
// 			}
// 
// 			isTagOpen = true;
// 			tagData = charStr;
// 			continue;
// 		}
// 
// 		if (charStr == ">") {
// 			if (!isTagOpen) {
// 				// Ignore loose '>' if not inside a tag (e.g. text content, though this parser ignores text content)
// 				continue;
// 			}
// 
// 			tagData += charStr;
// 
// 			// Check if it's a self-closing tag or closing tag
// 			// tagData contains the full tag including < and >
// 			// e.g. <tag> or </tag> or <tag />
// 			
// 			local isSelfClosing = (tagData.len() > 3 && tagData.slice(tagData.len()-2, tagData.len()-1) == "/");
// 			local isClosing = (tagData.len() > 2 && tagData.slice(1, 2) == "/");
// 
// 			if (isClosing) {
// 				// </tag>
// 				if (currentTag.parent) {
// 					currentTag = currentTag.parent;
// 				}
// 			} else {
// 				// <tag> or <tag />
// 				local newElement = ProcessTag(tagData, currentTag);
// 				if (!isSelfClosing) {
// 					currentTag = newElement;
// 				}
// 			}
// 
// 			tagData = "";
// 			isTagOpen = false;
// 			continue;
// 		}
// 
// 		if (isTagOpen) {
// 			tagData += charStr;
// 		}
// 	}
// 
// 	return rootElement;
// }
