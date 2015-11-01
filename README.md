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

After running `css-expand`, internal and external CSS style information are expanded as XML attributes.
```html
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:css="http://www.w3.org/1996/css">
  <head>
    <title>css-expand expample</title>
  </head>
  <body>
    <p class="red" css:color="red">This text has the color red.</p>
  </body>
</html>
```

