# css-expand
Parse CSS styles of an XHTML document and expand them as XML attributes (CSSa)

## Example

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

Invoke `css-expand` in your XProc pipeline. Please note 
that you have to include [xproc-utils](https://github.com/transpect/xproc-util).

```xml
<?xml version="1.0"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  xmlns:css="http://www.w3.org/1996/css" 
  version="1.0"
  name="test-css-expand">

  <p:input port="source" primary="true">
    <p:documentation>an XHTML document</p:documentation>
  </p:input>
  
  <p:output port="result" primary="true">
    <p:documentation>an XHTML document with CSSa attributes
    (in addition to its style elements/attributes/linked CSS
      stylesheets)</p:documentation>
  </p:output>
  
  <p:import href="css.xpl"/>

  <css:expand name="expand">
    <p:input port="stylesheet">
      <p:document href="../xsl/css-parser.xsl"/>
    </p:input>
  </css:expand>

</p:declare-step>
```


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

