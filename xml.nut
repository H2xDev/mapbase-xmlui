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

function XML::AddChild(parent, child) {
	child.parent = parent;
	parent.children.append(child);
}

function XML::Replace(source, what, by, recursive = false) {
  if (source.len() < what.len()) return source;

  for (local i = 0; i <= source.len() - what.len(); i++) {
    local a = source.slice(i, i + what.len());

    if (a == what) {
      if (!recursive) {
        return source.slice(0, i)
          + by
          + source.slice(i + what.len());
      }

      return source.slice(0, i)
        + by
        + Replace(source.slice(i + what.len()), what, by, recursive);
    }
  }

  return source;
}

function XML::PushError(message) {
	Print("XMLerror: " + message);
}

function XML::ProcessTag(tagData, parent) {
	local tagNameRegex = regexp("<([a-z]+)");
	local captureData = tagNameRegex.capture(tagData);
	if (!captureData)  {
		printl("Failed to parse tag: " + tagData);
		return;
	}

	local tagName = tagData.slice(captureData[1].begin, captureData[1].end);
	local element = CreateElement(tagName);

	AddChild(parent, element);

	local propsRegex = regexp("(\\w+)=\"(.+)\"");
	if (!captureData) return element;

	local lastCaptured = 0;

	captureData = propsRegex.capture(tagData);

	while (captureData) {
		local propName = tagData.slice(captureData[1].begin, captureData[1].end);
		local propValue = tagData.slice(captureData[2].begin, captureData[2].end);

		element.props[propName] <- propValue;

		lastCaptured = captureData[0].end;
		captureData = propsRegex.capture(tagData, lastCaptured);
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
	fileData = Replace(fileData, "\n", "", true);

	local rootElement = CreateElement("root");

	local isInComment = false;
	local isTagOpen = false;

	local isOpenTag = false;
	local isCloseTag = false;
	local isCommentTag = false;

	local currentTag = rootElement;
	local tagData = "";
	local prevChar = "";
	local tagContent = "";

	for (local i = 0; i < fileData.len(); i++) {
		local char = format("%c", fileData[i]);
		local prevChar = i > 0 
			? format("%c", fileData[i - 1])
			: "";

		if (isInComment) {
			tagData += char;
		}

		if (tagData.len() > 3 && tagData.slice(-4) == "<!--") {
			isInComment = true;
			isTagOpen = false;
			isCloseTag = false;
			isOpenTag = false;
			tagData += char;
			continue;
		}

		if (tagData.len() > 2 && tagData.slice(-3) == "-->") {
			isInComment = false;
			printl("Comment: " + tagData);
			tagData = "";
			continue;
		}

		if (isInComment) continue;

		if (char == "<") {
			if (isTagOpen) {
				return Errors.UNEXPECTED_TAG_OPEN;
			}

			isTagOpen = true;
			tagData += char;
			continue;
		}


		if (char != "/" && prevChar == "<") {
			isOpenTag = true;
		} else if (char == "/" && prevChar == "<") {
			isCloseTag = true;
		}

		if (char == ">") {
			if (!isTagOpen) {
				return Errors.UNEXPECTED_TAG_CLOSE;
			}

			tagData += char;

			if (isOpenTag) {
				currentTag = ProcessTag(tagData, currentTag);
			}

			if (isCloseTag || prevChar == "/") {
				currentTag = currentTag.parent;
			}

			tagData = "";
			isTagOpen = false;
			isOpenTag = false;
			isCloseTag = false;
			continue;
		}

		if (char == "/" && prevChar == "<") {
			isCloseTag = true;
			tagData += char;
			continue;
		}

		tagData += char;
	}

	return rootElement;
}
