<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xslout="bogo"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tr="http://transpect.io"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:css="http://www.w3.org/1996/css"
  version="2.0"
  exclude-result-prefixes="xs">

  <xsl:import href="css-util.xsl"/>
  
  <xsl:output indent="yes" />

  <xsl:param name="base-uri" select="base-uri(/*)" as="xs:string" />

  <xsl:template match="/">
    <css xmlns="http://www.w3.org/1996/css">
      <xsl:choose>
        <xsl:when test="matches(base-uri(/*), '^file:/')">
          <xsl:attribute name="xml:base" select="base-uri(/*)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'Spurious base URI: ', base-uri(/*)"/>      
        </xsl:otherwise>
      </xsl:choose>
      
<!--      <css xmlns="http://www.w3.org/1996/css" xml:base="{base-uri(/*)}">-->
      <xsl:variable name="extracted-css">
				<xsl:apply-templates select="html:html/html:head/(html:link[@rel eq 'stylesheet'] union html:style)" mode="extract-css" />
			</xsl:variable>
			<xsl:apply-templates select="$extracted-css" mode="add-position" /> 
    </css>
  </xsl:template>

  <xsl:function name="tr:external-css-file-available" as="xs:boolean">
    <xsl:param name="href-attr-or-css-url-value" as="xs:string"/>
    <xsl:param name="baseuri" as="xs:string"/>
    <xsl:variable name="resolved" as="xs:anyURI"
      select="resolve-uri($href-attr-or-css-url-value, $baseuri)"/>
    <xsl:choose>
      <xsl:when test="unparsed-text-available($resolved, 'UTF-8')">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:when test="unparsed-text-available($resolved, 'CP1252')">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="tr:resolve-css-file-content" as="xs:string?">
    <xsl:param name="href-attr-or-css-url-value" as="xs:string"/>
    <xsl:param name="baseuri" as="xs:string"/>
    <xsl:variable name="resolved" as="xs:anyURI"
      select="resolve-uri($href-attr-or-css-url-value, $baseuri)"/>
    <xsl:choose>
      <xsl:when test="unparsed-text-available($resolved, 'UTF-8')">
        <xsl:sequence select="unparsed-text($resolved, 'UTF-8')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="unparsed-text-available($resolved, 'CP1252')">
            <xsl:sequence select="unparsed-text($resolved, 'CP1252')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>External stylesheet '<xsl:value-of select="$href-attr-or-css-url-value"/>' 
(resolved as <xsl:value-of select="$resolved"/>) not found
or wrong encoding. Supported encodings: UTF-8, CP1252 (the latter should work for ISO-8859-1, too)</xsl:message>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="html:link[@type eq 'text/css']" mode="extract-css" as="element(*)*">
    <xsl:variable name="external-css" as="xs:string?"
      select="tr:resolve-css-file-content(@href, $base-uri)"/>
    <xsl:sequence select="if($external-css)
                          then tr:extract-css($external-css, resolve-uri(@href, $base-uri))
                          else ()"/>
  </xsl:template>

  <xsl:template match="html:style" mode="extract-css">
    <xsl:sequence select="tr:extract-css(string-join(for $n in node() return $n, ''), 'file://internal')" />
  </xsl:template>

  <xsl:function name="tr:extract-css" as="element(*)*">
    <xsl:param name="raw-css" as="xs:string?"/>
    <xsl:param name="origin" as="xs:string"/>
    <xsl:variable name="prelim" as="element(css:raw)">
      <raw xmlns="http://www.w3.org/1996/css">
        <xsl:analyze-string select="($raw-css, '')[1]" regex="/\*.+?\*/" flags="s">
          <xsl:matching-substring>
            <comment xmlns="http://www.w3.org/1996/css" origin="{$origin}">
              <xsl:sequence select="."/>
            </comment>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:analyze-string select="." regex="[;\{{\}}]">
              <xsl:matching-substring>
                <xsl:choose>
                  <xsl:when test=". = ';'">
                    <semicolon xmlns="http://www.w3.org/1996/css">
                      <xsl:value-of select="."/>
                    </semicolon>
                  </xsl:when>
                  <xsl:when test=". = '{'">
                    <start-token xmlns="http://www.w3.org/1996/css">
                      <xsl:value-of select="."/>
                    </start-token>
                  </xsl:when>
                  <xsl:otherwise>
                    <end-token xmlns="http://www.w3.org/1996/css">
                      <xsl:value-of select="."/>
                    </end-token>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:matching-substring>
              <xsl:non-matching-substring>
                <xsl:value-of select="."/>
              </xsl:non-matching-substring>
            </xsl:analyze-string>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </raw>
    </xsl:variable>
    <xsl:for-each-group select="$prelim/node()" 
      group-ending-with="css:end-token[tr:index-of($prelim/css:end-token, .) = count(preceding-sibling::css:start-token)]
                         | css:semicolon[(count(preceding-sibling::css:end-token) = count(preceding-sibling::css:start-token))]">
      <xsl:sequence select="current-group()/self::css:comment"/>
      <xsl:variable name="non-comment" as="element(css:non-comment)">
        <non-comment xmlns="http://www.w3.org/1996/css">
          <xsl:sequence select="current-group()[not(self::css:comment)]"/>
        </non-comment>
      </xsl:variable> 
      <xsl:variable name="string-content" as="xs:string" 
        select="normalize-space(string-join($non-comment, ''))"/>
      <xsl:if test="not(matches($string-content, '^@'))">
        <xsl:element name="ruleset" xmlns="http://www.w3.org/1996/css">
          <xsl:attribute name="origin" select="$origin"/>
          <xsl:element name="raw-css">
            <xsl:value-of select="$string-content"/>
          </xsl:element>
          <!-- separate selectors from declarations -->
          <xsl:call-template name="selectors">
            <xsl:with-param name="raw-selectors" 
              select="normalize-space(string-join( $non-comment/text()[not(preceding::css:start-token)], ''))"/>
          </xsl:call-template>
          <xsl:call-template name="declarations">
            <xsl:with-param name="raw-declarations" select="normalize-space(replace($string-content, '^[^\{]*\{(.*)\}$', '$1'))"/>
            <xsl:with-param name="origin" select="$origin" tunnel="yes"/>
          </xsl:call-template>
        </xsl:element>
      </xsl:if>
      <xsl:if test="matches(normalize-space($string-content), '^@')">
        <xsl:call-template name="at-rules">
          <xsl:with-param name="at-rule" select="$string-content"/>
          <xsl:with-param name="origin" select="$origin" tunnel="yes"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:for-each-group>    
  </xsl:function>

  <xsl:variable name="css:pseudo-classes-regex" select="':(first-child|last-child|link|visited|hover|active|focus|lang|first-line|first-letter|before|after)'" as="xs:string"/>

  <xsl:template name="selectors">
    <xsl:param name="raw-selectors" />
    <xsl:for-each select="distinct-values(tokenize($raw-selectors, '\s*,\s*'))">
      <xsl:element name="selector" xmlns="http://www.w3.org/1996/css">
        <xsl:attribute name="raw-selector" select="." />
        
        <xsl:if test="matches(., $css:pseudo-classes-regex)">
          <xsl:variable name="pseudo" as="node()*">
            <xsl:analyze-string select="." regex="{$css:pseudo-classes-regex}">
              <xsl:matching-substring>
                <xsl:value-of select="regex-group(1)" />
              </xsl:matching-substring>
              <xsl:non-matching-substring/>
            </xsl:analyze-string>
          </xsl:variable>
          <xsl:attribute name="pseudo">
            <xsl:for-each select="$pseudo">
              <xsl:value-of select="concat(if (position() gt 1) then ' ' else '', .)" />
            </xsl:for-each>
          </xsl:attribute>
        </xsl:if>
        <!-- transform selector to xpath -->
        <xsl:variable name="selector-as-xpath" select="tr:resolve-combinators(.)" />
        <!-- <xsl:attribute name="priority" select="tr:getPriority($selector-as-xpath)" /> -->
        <xsl:attribute name="priority" select="tr:getPriority(.)" />
        <xsl:value-of select="$selector-as-xpath" />
      </xsl:element>
    </xsl:for-each>
  </xsl:template>



  <xsl:function name="tr:selector2xpath" as="xs:string">
    <xsl:param name="raw-selector" as="xs:string"/>
    <xsl:variable name="resolve-attributes" as="xs:string">
      <xsl:value-of select="tr:resolve-attributes($raw-selector)"/>
    </xsl:variable>
    <xsl:variable name="resolve-pseudo-classes" as="xs:string">
      <xsl:value-of select="tr:resolve-pseudo-classes($resolve-attributes)"/>
    </xsl:variable>
    <xsl:variable name="resolve-classes" as="xs:string">
      <xsl:value-of select="tr:resolve-classes($resolve-pseudo-classes)"/>
    </xsl:variable>
    <xsl:variable name="resolve-ids" as="xs:string">
      <xsl:value-of select="tr:resolve-ids($resolve-classes)"/>
    </xsl:variable>
    <xsl:variable name="prelim" as="xs:string*">
      <xsl:for-each select="$resolve-ids">
        <xsl:analyze-string select="." regex="(^|[/])(\[)">
          <xsl:matching-substring>
            <xsl:sequence select="regex-group(1)" />
            <xsl:text>*</xsl:text>
            <xsl:sequence select="regex-group(2)" />
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:value-of select="." />
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:for-each>  
    </xsl:variable>
    <!-- empty $prelim may occur if the raw selector is just ':before', for example -->
    <xsl:sequence select="string-join((if (starts-with(($prelim[normalize-space()])[1], '*')) then '' else '*:', if (empty($prelim)) then '*' else $prelim), '')"/>
  </xsl:function>

  <xsl:function name="tr:resolve-combinators" as="xs:string">
    <xsl:param name="selector" as="xs:string"/>
    <xsl:variable name="combinators" select="'[+> ]'" as="xs:string"/>
    <xsl:variable name="parsed" as="element(*)*">
      <!-- there is no negative lookahead in xpath2, such as  ?([+>~ ])(?!=) ? 
           to distinguish between [title~=bar] and a~span
           http://stackoverflow.com/questions/18144037/why-xslt-lookahead-pattern-is-not-worked-in-saxon-he-9-4-java
      -->
      <xsl:analyze-string select="normalize-space($selector)" regex=" ?([a-z\-]*\[[a-z\-\s]+[~\^\$\*]?=?[-_\s':a-zA-Z0-9]*\]) ?">
        <xsl:matching-substring>
          <selector>
            <xsl:sequence select="replace(regex-group(1), '''', '')"/>
          </selector>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:sequence select="tr:analyze-combinators-and-selectors(.)"/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="count($parsed) eq 0">
        <xsl:sequence select="''"/>
      </xsl:when>
      <xsl:when test="$parsed[last()]/self::combinator">
        <xsl:message terminate="yes" select="'css-parser.xsl: selector ', normalize-space($selector), ' ends with a combinator'"/>
      </xsl:when>
      <xsl:when test="$parsed[1]/self::combinator">
        <xsl:message terminate="yes" select="'css-parser.xsl: selector ', normalize-space($selector), ' starts with a combinator'"/>
      </xsl:when>
      <xsl:when test="count($parsed) mod 2 eq 0">
        <xsl:message terminate="yes" select="'css-parser.xsl: selector ', normalize-space($selector), ' must have alternating combinators and sub-selectors'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="tr:combined-selector2xpath($parsed)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="tr:analyze-combinators-and-selectors" as="element()+">
    <xsl:param name="selector" as="xs:string"/>
    <xsl:analyze-string select="normalize-space($selector)" regex=" ?([+>~ ]) ?">
      <xsl:matching-substring>
        <combinator>
          <xsl:sequence select="regex-group(1)"/>
        </combinator>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <selector>
          <xsl:sequence select="."/>
        </selector>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
  <xsl:function name="tr:combined-selector2xpath" as="xs:string">
    <xsl:param name="parsed" as="element(*)+"/><!-- selector, (combinator, selector)* -->
    <xsl:variable name="result-seq" as="xs:string+">
      <xsl:choose>
        <xsl:when test="count($parsed) eq 1">
          <xsl:sequence select="tr:selector2xpath($parsed)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="last-selector" select="$parsed[last()]" as="element(selector)"/>
          <xsl:variable name="last-combinator" select="$parsed[last() - 1]" as="element(combinator)"/>
          <xsl:variable name="remainder" select="$parsed[position() lt (last() - 1)]" as="element(*)+"/>
          <xsl:choose>
            <xsl:when test="string($last-combinator) = '&gt;'">
              <xsl:sequence select="tr:selector2xpath($last-selector)"/>
              <xsl:text>[parent::</xsl:text>
              <xsl:sequence select="tr:combined-selector2xpath($remainder)"/>
              <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:when test="string($last-combinator) = ' '">
              <!-- Eventually rewrite XPath generation so that we’re able to use // again. 
                   But this proved difficult with this right-to-left recursive parsing of
                   simple selectors. -->
              <xsl:sequence select="tr:selector2xpath($last-selector)"/>
              <xsl:text>[ancestor::</xsl:text>
              <xsl:sequence select="tr:combined-selector2xpath($remainder)"/>
              <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:when test="string($last-combinator) = '+'">
              <xsl:sequence select="tr:selector2xpath($last-selector)"/>
              <xsl:text>[preceding-sibling::*[1]/self::</xsl:text>
              <xsl:sequence select="tr:combined-selector2xpath($remainder)"/>
              <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:when test="string($last-combinator) = '~'">
              <xsl:sequence select="tr:selector2xpath($last-selector)"/>
              <xsl:text>[preceding-sibling::</xsl:text>
              <xsl:sequence select="tr:combined-selector2xpath($remainder)"/>
              <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">css-parser.xsl: Unknown combinator "<xs:value-of select="$last-combinator"
                />".</xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="string-join($result-seq, '')"/>
  </xsl:function>

  <xsl:function name="tr:resolve-pseudo-classes"><!-- processes pseudo-elements, too -->
    <xsl:param name="var-resolve-pseudo-classes" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="matches($var-resolve-pseudo-classes, $css:pseudo-classes-regex)">
        <xsl:analyze-string select="$var-resolve-pseudo-classes" regex="(^|[^:]*):([^:.]*)">
          <xsl:matching-substring>
            <xsl:choose>
              <xsl:when test="regex-group(2) = 'first-child'">
                <xsl:value-of select="tr:resolve-pseudo-classes(regex-group(1))" />
                <xsl:text>[not(preceding-sibling::*)]</xsl:text>
              </xsl:when>
              <xsl:when test="regex-group(2) = 'last-child'">
                <xsl:value-of select="tr:resolve-pseudo-classes(regex-group(1))" />
                <xsl:text>[not(following-sibling::*)]</xsl:text>
              </xsl:when>
              <xsl:when test="regex-group(2) = ('link', 'visited')">
                <xsl:value-of select="tr:resolve-pseudo-classes(regex-group(1))" />
                <xsl:text>[exists(@href)]</xsl:text>
              </xsl:when>
              <xsl:when test="regex-group(2) = ('hover', 'active', 'focus', 'first-line', 'first-letter', 'before', 'after')">
                <xsl:value-of select="tr:resolve-pseudo-classes(regex-group(1))" />
              	<xsl:sequence select="concat('[@css:pseudo_', regex-group(2), ']')"/>
              </xsl:when>
              <xsl:when test="matches(regex-group(2), '^lang')">
                <xsl:value-of select="tr:resolve-pseudo-classes(regex-group(1))" />
                <xsl:text>[matches(ancestor-or-self::*/@lang,'</xsl:text>
                <xsl:value-of select="substring-before(substring-after(., '('), ')')" />
                <xsl:text>')]</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="." />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:value-of select="." />
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$var-resolve-pseudo-classes" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="tr:resolve-classes">
    <xsl:param name="var-resolve-classes" />
    <xsl:analyze-string select="$var-resolve-classes" regex="^([^=']*)\.([^\.:/\[]+)">
      <xsl:matching-substring>
        <xsl:value-of select="tr:resolve-classes(regex-group(1))" />
        <xsl:text>[matches(@class,'(^|\s)</xsl:text>
        <xsl:value-of select="regex-group(2)" />
        <xsl:text>(\s|$)')]</xsl:text>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="." />
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="tr:resolve-ids">
    <xsl:param name="var-resolve-ids" />
    <xsl:analyze-string select="$var-resolve-ids" regex="#([^\.:/\[]+)">
      <xsl:matching-substring>
        <xsl:text>[@id='</xsl:text>
        <xsl:value-of select="regex-group(1)" />
        <xsl:text>']</xsl:text>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="." />
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="tr:resolve-attributes" as="xs:string">
    <xsl:param name="var-resolve-attributes" as="xs:string"/>
    <xsl:variable name="quots">"</xsl:variable>
    <xsl:variable name="tokens" as="xs:string+">
      <xsl:analyze-string select="$var-resolve-attributes"
        regex="\[(([^|~=@\^\*\$]*)?(\^=|=|~=|\|=|\*=|\$=)?{$quots}?([^\[@]*?){$quots}?)\]">
        <xsl:matching-substring>
          <xsl:text>[</xsl:text>
          <xsl:choose>
            <xsl:when test="regex-group(3) = ''">
              <xsl:text>exists(@</xsl:text>
              <xsl:value-of select="regex-group(1)"/>
              <xsl:text>)</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '='">
              <xsl:text>@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>='</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>'</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '~='">
              <xsl:text>matches(@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>,'(^|\s)</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>(\s|$)')</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '|='">
              <xsl:text>matches(@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>,'^</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>&#x2d;?$')</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '^='">
              <xsl:text>matches(@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>,'^</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>')</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '$='">
              <xsl:text>matches(@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>,'</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>$')</xsl:text>
            </xsl:when>
            <xsl:when test="regex-group(3) = '*='">
              <xsl:text>matches(@</xsl:text>
              <xsl:value-of select="regex-group(2)"/>
              <xsl:text>,'</xsl:text>
              <xsl:value-of select="regex-group(4)"/>
              <xsl:text>')</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="."/>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>]</xsl:text>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:value-of select="."/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:sequence select="string-join($tokens, '')"/>
  </xsl:function>

  
  <xsl:function name="tr:getPriority">
    <xsl:param name="selector" />
    <!--a, @style-->
    <xsl:value-of select="'0'" />
    <xsl:text>,</xsl:text>
    <!--b, count id attributes-->
    <xsl:value-of select="tr:getCounts($selector, '#')[1]" />
    <xsl:text>,</xsl:text>
    <!--c, count attributes and pseudo-classes-->
    <xsl:value-of select="tr:getCounts($selector, '(\[(([^|~=@]*)?(=|~=|\|=)?[^\[@]*?)\]|\.)')[1] + tr:getCounts($selector, ':(first-child|last-child|link|visited|hover|active|focus|lang)')[1]" />
    <xsl:text>,</xsl:text>
    <!--d, count elements and pseudo-elements-->
    <xsl:value-of select="tr:getCounts($selector, '[+> ]')[2] + tr:getCounts($selector, ':(first-line|first-letter|before|after)')[1]" />
  </xsl:function>

  <xsl:function name="tr:getCounts">
    <xsl:param name="selector" />
    <xsl:param name="regex" />
    <xsl:variable name="find-number">
      <xsl:analyze-string select="$selector" regex="\s*({$regex})\s*">
        <xsl:matching-substring>
          <counter />
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:if test="matches(., '^[^.*]')">
            <restcounter />
          </xsl:if>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:value-of select="count($find-number/counter)" />
    <xsl:value-of select="count($find-number/restcounter)" />
  </xsl:function>


  <!-- at rules -->

  <xsl:template name="at-rules">
    <xsl:param name="at-rule" as="xs:string" />
    <xsl:param name="origin" as="xs:string" tunnel="yes"/>
    <xsl:variable name="base-uri-also-considering-current-css-file" as="xs:string"
      select="($origin[not(. = 'file://internal')], $base-uri)[1]"/>
    <xsl:for-each select="tokenize($at-rule, '@')[matches(., '\S+')]">
      <xsl:variable name="type">
        <xsl:value-of select="substring-before(replace(., '\s\s+|\{', '&#x20;'), '&#x20;')" />
      </xsl:variable>
      <xsl:variable name="import-css">
        <xsl:analyze-string select="." regex="import\s*(url\(\s*)?[&#34;&#39;](.*?)[&#34;&#39;]\s*\)?\s*([^;]+)?.*$">
          <xsl:matching-substring>
            <xsl:element name="css"><xsl:value-of select="regex-group(2)" /></xsl:element>
            <xsl:element name="media"><xsl:value-of select="regex-group(3)" /></xsl:element>
          </xsl:matching-substring>
        </xsl:analyze-string>
      </xsl:variable>
      <xsl:element name="atrule" xmlns="http://www.w3.org/1996/css">
        <xsl:attribute name="type" select="$type" />
        <xsl:attribute name="origin" select="$origin" />
        <xsl:if test="$type eq 'import'">
          <xsl:choose>
            <xsl:when test="tr:external-css-file-available($import-css/css, $base-uri-also-considering-current-css-file )">
              <xsl:attribute name="resolved" select="'true'"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="resolved" select="'false'"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
        <raw-css>
          <xsl:value-of select="concat('@', .)" />  
        </raw-css>
        <!-- resources declared with css url() -->
        <xsl:variable name="css-url-regex" select="'.*?url\(''?(.+?)''?\).*'" as="xs:string"/>
        <xsl:variable name="inner" as="xs:string" select="normalize-space(replace(., '^[^\{]*\{(.*)\}$', '$1'))"/>
        <xsl:if test="$type = ('font-face', 'page')">
          <xsl:call-template name="declarations">
            <xsl:with-param name="raw-declarations" select="$inner"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$type = 'media'">
          <xsl:for-each select="tokenize(
                                  normalize-space(replace(., 'media\s+([^\{]+)\s*\{(.*)\}$', '$1')),
                                  '\s*,\s*'
                                )">
            <condition>
              <xsl:value-of select="."/>
            </condition>
          </xsl:for-each>
          <xsl:sequence select="tr:extract-css($inner, $origin)"/>
        </xsl:if>
      </xsl:element>
      <xsl:if test="$type='import'">
        <xsl:sequence select="tr:extract-css(
                                tr:resolve-css-file-content($import-css/css, $base-uri-also-considering-current-css-file), 
                                resolve-uri($import-css/css, $base-uri-also-considering-current-css-file)
                              )"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- mode add-position (post-process is included here only for compatibility with the REx-based parser) -->
  
  <xsl:template match="* | @*" mode="add-position post-process">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*:selector" mode="add-position">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="position" select="count(parent::*:ruleset/preceding-sibling::*:ruleset)+1" />
      <xsl:apply-templates select="node()" mode="#current" />
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>