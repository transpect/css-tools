<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tr="http://transpect.io"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:css="http://www.w3.org/1996/css"
    xmlns="http://www.w3.org/1996/css"
    version="2.0"
    exclude-result-prefixes="xs">

  <!-- CSS parser by Grit Rolewski, le-tex publishing services GmbH.
       Integrated into epubcheck-xproc by Gerrit Imsieke.
       See ../README for copyright information
    -->
  
  <xsl:variable name="css-shorthand-properties" as="xs:string+"
    select="('background', 'border', 'border-left', 'border-right', 'border-top', 'border-bottom', 
             'font', 'list-style', 'margin', 'padding', 'text-decoration')" />
  
  <xsl:template name="declarations" xpath-default-namespace="http://www.w3.org/1996/css">
    <xsl:param name="raw-declarations" as="xs:string"/>
    <xsl:param name="origin" tunnel="yes" as="xs:string?"/>
    <xsl:for-each select="tokenize($raw-declarations, ';\s*')[matches(., '\S')]">
      <xsl:variable name="prop" select="normalize-space(substring-before(., ':'))" />
      <xsl:variable name="_val" select="replace(normalize-space(substring-after(., ':')), '\s?!important', '')" />
      <xsl:variable name="check-shorthand-property" select="$prop=$css-shorthand-properties" as="xs:boolean" />
      <xsl:choose>
        <xsl:when test="$check-shorthand-property">
          <shorthand property="{$prop}" value="{$_val}" num="{position()}"/>
          <xsl:sequence select="tr:handle-shorthand-properties($prop, $_val, string(position()))" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
            <xsl:attribute name="property" select="$prop"/>
            <xsl:attribute name="value" select="$_val"/>
            <xsl:if test="matches(substring-after(., ':'), '!important')">
              <xsl:attribute name="important" select="'yes'"/>
            </xsl:if>
            <xsl:variable name="atts" as="element(atts)">
              <atts>
                <xsl:analyze-string select="$_val" regex=".*?(url|format)\s*\(\s*'?([^\)]+?)'?\s*\)(\s*,)?">
                  <xsl:matching-substring>
                    <att xmlns="" name="{regex-group(1)}" val="{regex-group(2)}"/>
                    <xsl:if test="normalize-space(regex-group(3))">
                      <sep xmlns=""/>
                    </xsl:if>
                  </xsl:matching-substring>
                </xsl:analyze-string>
              </atts>  
            </xsl:variable>
            <xsl:for-each-group select="$atts/*" group-starting-with="*:sep">
              <xsl:choose>
                <xsl:when test="current-group()/@name = 'url'">
                  <resource src="{resolve-uri(current-group()[@name = 'url']/@val, $origin)}">
                    <xsl:for-each select="current-group()[not(self::*:sep)][not(@name = 'url')]">
                      <xsl:attribute name="{@name}" select="@val"/>  
                    </xsl:for-each>
                  </resource>
                </xsl:when>
              </xsl:choose>
            </xsl:for-each-group>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>


  <xsl:function name="tr:handle-shorthand-properties" as="element(*)*">
    <!-- this is overridden in REx_css-parser.xsl where it will be applied in mode post-process
         If you want to improve REx parser shorthand handling, turn to the overridden function -->
    <xsl:param name="prop" as="xs:string"/>
    <xsl:param name="val" as="xs:string"/>
    <xsl:param name="id" as="xs:string"/>
    <xsl:variable name="out" as="element(*)*">
      <xsl:choose>
        <xsl:when test="$prop=('margin', 'padding', 'border-style', 'border-color', 'border-width')">
          <xsl:variable name="val-seq" select="tokenize($val, ' ')"/>
          <xsl:variable name="new-props">
            <props count="1">
              <top seq="1"/>
              <right seq="1"/>
              <bottom seq="1"/>
              <left seq="1"/>
            </props>
            <props count="2">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="1"/>
              <left seq="2"/>
            </props>
            <props count="3">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="3"/>
              <left seq="2"/>
            </props>
            <props count="4">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="3"/>
              <left seq="4"/>
            </props>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="count($val-seq) le 4">
              <xsl:for-each select="$new-props/*:props[number(@count) eq count($val-seq)]/*">
                <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
                  <xsl:attribute name="property"
                    select="concat(replace($prop, '-.*$', ''), '-', name(), substring-after($prop, 'border'))"/>
                  <xsl:attribute name="value" select="$val-seq[position() eq number(current()/@seq)]"/>
                  <xsl:attribute name="shorthand" select="$id"/>
                </xsl:element>
              </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message>ERROR! There is something wrong with property count in shorthand property "<xsl:value-of
                  select="$prop"/>": <xsl:value-of select="$val"/></xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>

        <xsl:when test="$prop=('border')">
          <xsl:call-template name="border-vals">
            <xsl:with-param name="all-pos" select="'top right bottom left'"/>
            <xsl:with-param name="val" select="$val"/>
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>
        </xsl:when>

        <xsl:when test="matches($prop, '^border-(left|right|top|bottom)$')">
          <xsl:call-template name="border-vals">
            <xsl:with-param name="all-pos" select="substring-after($prop, 'border-')"/>
            <xsl:with-param name="val" select="$val"/>
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>
        </xsl:when>

        <xsl:when test="$prop='background'">
          <xsl:variable name="new-vals">
            <vals>
              <image pos-vals="(none|url)"/>
              <attachment pos-vals="(scroll|fixed)"/>
              <repeat pos-vals="^(no-repeat|repeat|repeat-x|repeat-y)"/>
              <color pos-vals="(transparent|\(|[a-z]+|#[0-9a-fA-F]+)"/>
              <position pos-vals="(left|right|top|bottom|center|[.0-9]+(%|em|ex|px|in|cm|mm|pt|pc))"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize(replace($val, ',\s', ','), ' ')">
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:image/@pos-vals)">image</xsl:when>
                <xsl:when test="matches(., $new-vals//*:attachment/@pos-vals)">attachment</xsl:when>
                <xsl:when test="matches(., $new-vals//*:repeat/@pos-vals)">repeat</xsl:when>
                <xsl:when test="matches(., $new-vals//*:position/@pos-vals)">position</xsl:when>
                <xsl:when test="matches(., $new-vals//*:color/@pos-vals)">color</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
              <xsl:attribute name="property" select="concat('background-', $current-val)"/>
              <xsl:attribute name="value" select="."/>
              <xsl:attribute name="shorthand" select="$id"/>
            </xsl:element>
          </xsl:for-each>
        </xsl:when>

        <xsl:when test="$prop='font'">
          <xsl:variable name="tokens" select="tokenize($val, ' ')" as="xs:string+"/>
          <xsl:choose>
            <xsl:when test="count($tokens) = 2">
              <!-- token 1 is size, token 2 is family -->
              <declaration xmlns="http://www.w3.org/1996/css" property="font-size" value="{$tokens[1]}" shorthand="{$id}"/>
              <declaration xmlns="http://www.w3.org/1996/css" property="font-family" value="{$tokens[2]}" shorthand="{$id}"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:for-each select="('style', 'variant', 'weight', 'size', 'family')">
                <xsl:variable name="current-pos" select="position()"/>
                <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
                  <xsl:attribute name="property" select="concat('font-', .)"/>
                  <xsl:choose>
                    <xsl:when test="$val = 'inherit'">
                      <xsl:attribute name="value" select="$val"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:attribute name="value"
                        select="$tokens[if ($current-pos le 4) then (position() eq $current-pos) else (position() ge 5)]"/>
                    </xsl:otherwise>
                  </xsl:choose>
                  <xsl:attribute name="shorthand" select="$id"/>
                </xsl:element>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
          
        </xsl:when>

        <xsl:when test="$prop='list-style'">
          <xsl:variable name="new-vals">
            <vals>
              <type
                pos-vals="(circle|square|disc|decimal|lower-roman|upper-roman|decimal-leading-zero|lower-greek|lower-latin|upper-latin|armenian|georgian|none)"/>
              <position pos-vals="(inside|outside)"/>
              <image pos-vals="(none|url)"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize($val, ' ')">
            <xsl:variable name="current-pos" select="position()"/>
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:position/@pos-vals)">position</xsl:when>
                <xsl:when
                  test="matches(., $new-vals//*:type/@pos-vals) and (not(. eq 'none' and (exists(tokenize($val, ' ')[position() ne $current-pos][matches(., $new-vals//*:type/@pos-vals)]))) or (. eq 'none' and (exists(tokenize($val, ' ')[position() gt $current-pos][. eq 'none']))))"
                  >type</xsl:when>
                <xsl:when test="matches(., $new-vals//*:image/@pos-vals)">image</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
              <xsl:attribute name="property" select="concat('list-style-', $current-val)"/>
              <xsl:attribute name="value" select="."/>
              <xsl:attribute name="shorthand" select="$id"/>
            </xsl:element>
          </xsl:for-each>
        </xsl:when>

        <xsl:when test="$prop='text-decoration'">
          <xsl:variable name="new-vals">
            <vals>
              <style pos-vals="(solid|double|dotted|dashed|wavy)"/>
              <line pos-vals="(none|underline|overline|line-through|blink)"/>
              <color pos-vals="(transparent|\(|[a-z]+|#[0-9a-fA-F]+)"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize(replace($val, ',\s', ','), ' ')">
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:style/@pos-vals)">style</xsl:when>
                <xsl:when test="matches(., $new-vals//*:line/@pos-vals)">line</xsl:when>
                <xsl:when test="matches(., $new-vals//*:color/@pos-vals)">color</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="$current-val">
              <!--<css:declaration/>-->
              <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
                <xsl:attribute name="property" select="concat('text-decoration-', $current-val)"/>
                <xsl:attribute name="value" select="."/>
                <xsl:attribute name="shorthand" select="$id"/>
              </xsl:element>
            </xsl:if>
          </xsl:for-each>
        </xsl:when>

        <xsl:otherwise>
          <xsl:message>WARNING! Shorthand property "<xsl:value-of select="$prop"/>" has not been implemented, yet!</xsl:message>
          <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
            <xsl:attribute name="property" select="$prop"/>
            <xsl:attribute name="value" select="$val"/>
            <xsl:attribute name="shorthand" select="$id"/>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="empty($out)">
      <xsl:message select="'Empty compound prop expansion for prop ', $prop, ' with value ', $val"/>
    </xsl:if>
    <xsl:sequence select="$out"/>
  </xsl:function>

  <xsl:function name="tr:index-of" as="xs:integer*">
    <xsl:param name="nodes" as="node()*"/>
    <xsl:param name="node" as="node()?"/>
    <xsl:sequence select="index-of(for $n in $nodes return generate-id($n), $node/generate-id())"/>
  </xsl:function>

  <xsl:template name="border-vals">
    <xsl:param name="all-pos" />
    <xsl:param name="val" />
    <xsl:param name="id" as="xs:string"/>
    <xsl:variable name="new-vals">
      <vals>
        <style pos-vals="(none|dotted|dashed|solid|double|groove|ridge|inset|outset)" />
        <width pos-vals="(thin|medium|thick|^[.0-9]+)" />
        <color pos-vals="(transparent|\(|[a-z]+|#[0-9a-fA-F]+)" />
      </vals>
    </xsl:variable>
    <xsl:for-each select="tokenize($all-pos, ' ')">
      <xsl:variable name="current-pos" select="." />
      <xsl:for-each select="tokenize(replace($val, ',\s', ','), ' ')">
        <xsl:variable name="current-val">
          <xsl:choose>
            <xsl:when test="matches(., $new-vals//*:style/@pos-vals)">style</xsl:when>
            <xsl:when test="matches(., $new-vals//*:width/@pos-vals)">width</xsl:when>
            <xsl:when test="matches(., $new-vals//*:color/@pos-vals)">color</xsl:when>
            <xsl:otherwise></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
          <xsl:attribute name="property" select="concat('border-', $current-pos, '-', $current-val)" />
          <xsl:attribute name="value" select="." />
          <xsl:attribute name="shorthand" select="$id" />
        </xsl:element>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

  <xsl:key name="class" match="*[@class]" use="tokenize(@class, '\s+')"/>
  <xsl:key name="id" match="*[@id]" use="@id"/>
</xsl:stylesheet>