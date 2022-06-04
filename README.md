# css:expand

Parse CSS styles of an XHTML document and expand them as XML attributes ([CSSa](https://github.com/le-tex/CSSa))

## Example 1

Consider this document as input:

```html
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>css-expand expample</title>
    <style type="text/css">
      .red {color:red}
    </style>
  </head>
  <body>
    <p class="red">This text has the color red.</p>
  </body>
</html>

```

Invoke `css:expand` in your XProc pipeline. Please note 
that you have to include [xproc-utils](https://github.com/transpect/xproc-util).

See [test-css-expand.xpl](https://github.com/transpect/css-tools/blob/master/xpl/test-css-expand.xpl) for an example pipeline.


After running `css-expand`, internal and external CSS style information are expanded as XML attributes.
```html
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" 
  xmlns:css="http://www.w3.org/1996/css">
  <head>
    <title>css-expand expample</title>
    <style type="text/css">
      .red {color:red}
    </style>
  </head>
  <body>
    <p class="red" css:color="red">This text has the color red.</p>
  </body>
</html>
```

## Example 2

This example contains an `xml-stylesheet` processing instruction as an additional CSS source. It also demonstrates the handling of 
shorthand properties and pseudo elements.

See [example2.xhtml](https://github.com/transpect/css-tools/blob/master/example/example2.xhtml) and [style2.css](https://github.com/transpect/css-tools/blob/master/example/style2.css)

Expanded output (`body` only):

```html
<body css:background-color="#eec">
  <div id="grid">
    <div id="reference-overlapped-red" css:color="red" css:font-style="normal" css:font-variant="normal" css:font-weight="normal" css:font-stretch="normal" css:font-size="100px" css:line-height="1" css:font-family="Ahem" css:grid-row="1" css:grid-column="1">R</div>
    <div id="test-overlapping-green" css:background-color="green" css:width="100px" css:height="100px" css:grid-row="1" css:grid-column="1" css:font-style="normal" css:font-variant="normal" css:font-weight="bold" css:font-stretch="normal" css:font-size="12px" css:line-height="120%" css:font-family="sans-serif"/>
  </div>
  <div class="foo" css:font-style="normal" css:font-variant="normal" css:font-weight="400" css:font-stretch="normal" css:font-size="80%" css:line-height="normal" css:font-family="'New Century Schoolbook', &#34;Palatino Linotype&#34;, serif">
    <p css:pseudo-after_content="' styled by style element'" css:pseudo-before_content="'styled by PI '" css:font-style="italic" css:font-variant="normal" css:font-weight="normal" css:font-stretch="normal" css:font-size="80%" css:line-height="normal" css:font-family="serif">Test</p>
  </div>
</body>
```

# css:parse

There is also a step `css:parse` in the same css.xpl library. This will only generate an XML representation from the CSS that was included per `link` or `style` elements (note that the input is expected to be in XHTML namespace; will add reading HTML5-serialized input later). 

The output, as generated by the [REx](http://bottlecaps.de/rex/)-generated parser for above `style`, looks like:

```xml
<parser-results xml:base="file:/C:/path/to/file.xhtml">
   <css origin="file://internal">
      <S>
      </S>
      <rule>
         <selectors_group>
            <selector>
               <simple_selector_sequence>
                  <class>
                     <TOKEN>.</TOKEN>
                     <IDENT>red</IDENT>
                  </class>
               </simple_selector_sequence>
            </selector>
         </selectors_group>
         <S> </S>
         <TOKEN>{</TOKEN>
         <declaration>
            <property>
               <IDENT>color</IDENT>
            </property>
            <TOKEN>:</TOKEN>
            <values>
               <value>
                  <IDENT>red</IDENT>
               </value>
            </values>
         </declaration>
         <TOKEN>}</TOKEN>
      </rule>
      <S>
    </S>
   </css>
</parser-results>
```

This parser output will then be transformed to an XML representation like this:

```xml
<css xmlns="http://www.w3.org/1996/css">
   <ruleset origin="file://internal">
      <raw-css xml:space="preserve">
        .red {color:red}
      </raw-css>
      <selector priority="0,0,1,0" position="1" raw-selector=".red">key('class', 'red')</selector>
      <declaration property="color" value="red"/>
   </ruleset>
</css>
```

There is no schema yet for this XML representation.

The text content of the selector elements are XPath expressions that will be used generating 
an XSLT stylesheet that, when applied to the input document, will yield the expanded document.

The purpose of expansion is to find out the actual styling that is applied to a document location, for example prior to Schematron checks for device compatibility or accessibility. Of course checking and possibly filtering the parsed CSS alone may be sufficient for quality control. In our EPUB builder, the CSS will be parsed and re-serialized by default. 

## Rationale for switching to an EBNF-based parser

We wanted to be able to parse stuff like `calc()`, `scale()`, `translateX()`, `rgba()` in a less cumbersome way than with regexes. 

## Comments and whitespace

There are customers who want to retain the comments in the re-serialized CSS. Comments in rules (in selectors and properties) have proved to be particularly difficult to handle. With the previous regex-based approach, we just split between the rules and if there were comments anywhere within a rule, they were pulled out of it and went immediately before it in the serialization. However, this is no longer possible with the REx-generated parser. 

REx knows a pragma, [`/* ws:definition */`](https://github.com/transpect/css-tools/commit/9e62b1da02856e72a02d07e60fa9c14be9eecc89#diff-2d7bf9880e9266456c02e71a533a4755L59), that allows to treat any named production rules as ignorable whitespace. We tried that, but apart from not allowing retention of comments, it conflicted with the descendant combinator, which happens to be just whitespace. So we (@fr4nze and @gimsieke) tried to use the [`/* ws:explicit */`] pragma in selectors, but this led to lexical ambiguities when comments were also part of the ignorable whitespace rules. If we solved this problem, we would still be losing the comments. So we now tried this: Whitespace is significant, but allowed in many places. Comments are allowed in less places, in particular not in the middle of a selector or in properties. If the parser encounters such a comment, it will raise an error. [This error will be caught](https://github.com/transpect/css-tools/commit/9e62b1da02856e72a02d07e60fa9c14be9eecc89#diff-b9619c16ea8c9baad938469e14e126aaR74), and the CSS input will be resubmitted with all comments stripped away by means of a regex. An appropriate error message will be produced on the report port, allowing users to move comments to safer places in the input. If comments may be ignored altogether, then also this error message may be ignored. 


