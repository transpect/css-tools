<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xslout="bogo"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tr="http://transpect.io"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns="http://www.w3.org/1996/css"
  version="2.0"
  xpath-default-namespace="http://www.w3.org/1996/css">
  
  <xsl:namespace-alias stylesheet-prefix="xslout" result-prefix="xsl"/>

  <xsl:param name="path-constraint" as="xs:string?" /><!-- e.g., '[parent::*:tr]' for expanding only HTML table cell attributes -->
  <xsl:param name="prop-constraint" as="xs:string?" /><!-- e.g., 'width padding-top padding-bottom' -->

  <xsl:output indent="yes" />

  <xsl:template match="/">
    <xsl:apply-templates mode="create-xsl" />
  </xsl:template>

  <xsl:template match="css" mode="create-xsl">
    <xslout:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tr="http://transpect.io" xmlns:css="http://www.w3.org/1996/css">
      <xsl:sequence select="document('css-util.xsl')/*/node()" />
      <xslout:template match="/">
        <xslout:variable name="add-css-info">
          <xslout:apply-templates mode="add-css-info" />
        </xslout:variable>
        <xslout:variable name="add-style-info">
          <xslout:apply-templates select="$add-css-info" mode="add-style-info" />
        </xslout:variable>
        <xslout:apply-templates select="$add-style-info" mode="handle-important-info" />
      </xslout:template>

      <xsl:for-each select="ruleset[declaration]/selector">
        <xsl:variable name="current-node" select="." />
        <xsl:variable name="class-attribute" select="if (matches(., '@class')) then replace(replace(., '.+?(\[matches\(@class,.\(\^\|\\s\)(.+?)\(\\s\|\$\))?', '$2 '), '\s+', ' ') else ''" />
        <xsl:variable name="leading-zero" select="if (string-length(@position) eq 1) then '000' else 
                                                  if (string-length(@position) eq 2) then '00' else 
                                                  if (string-length(@position) eq 3) then '0' else ''" />
        <xslout:template match="{.}{$path-constraint}" 
          priority="{number(concat(replace(@priority, ',', ''), '.', $leading-zero, @position))}" mode="add-css-info">
          <xslout:param name="last-pos" tunnel="yes">0</xslout:param>
          <xslout:variable name="class" select="'{normalize-space($class-attribute)}'" />
          <xslout:variable name="pos" select="index-of(tokenize(@class, ' '), $class)" />
          <xslout:copy>
            <xslout:apply-templates select="@*" mode="#current" />
            <xsl:for-each select="../declaration">
              <xsl:if test="empty($prop-constraint)
                            or
                            $prop-constraint = ''
                            or
                            tokenize($prop-constraint, '\s+') = string(@property)">
                <xslout:attribute 
                  name="{
                          concat(
                            if ($current-node/@pseudo) 
                              then concat('pseudo-', $current-node/@pseudo, '_') 
                              else '',
                            if (starts-with(@property, '-')) 
                              then '_' 
                              else '',
                            @property, 
                            if (@important='yes') 
                              then '_important' 
                              else ''
                          )
                        }" 
                  select="'{  
                            if(@property eq 'content') 
                            then @value 
                            else tr:strip-delims(@value)
                          }'" 
                  namespace="http://www.w3.org/1996/css"/>
              </xsl:if>
            </xsl:for-each>
            <xslout:variable name="more-attributes">
              <xslout:next-match>
                <xslout:with-param name="last-pos" select="$pos" />
              </xslout:next-match>
            </xslout:variable>
            <xslout:copy-of select="$more-attributes/*[1]/@*[not(contains('{for $i in $current-node/../declaration/@property return concat($i, if ($i/parent::*/@important='yes') then '_important' else '')}', local-name()))]" />
            <xslout:apply-templates select="node()" mode="#current" />
          </xslout:copy>
        </xslout:template>
      </xsl:for-each>

      <xslout:template match="*[@style[not(matches(., '(background-image|margin:)'))]]" mode="add-style-info">
        <xslout:variable name="style-info" as="element(*)*"><!-- css:shorthand, css:declaration -->
          <xslout:call-template name="declarations">
            <xslout:with-param name="raw-declarations" select="@style"/>
            <xslout:with-param name="origin" select="'internal'" tunnel="yes"/>
          </xslout:call-template>
        </xslout:variable>
        <xslout:copy>
          <xslout:apply-templates select="@*" mode="#current" />
          <xslout:for-each select="$style-info/self::css:declaration">
            <xslout:attribute name="{{concat(if (starts-with(@property, '-')) then '_' else '',
                                             @property,
                                             if (@important='yes') then '_important' else ''
                                    )}}" select="@value" namespace="http://www.w3.org/1996/css" />
          </xslout:for-each>
          <xslout:apply-templates select="node()" mode="#current" />
        </xslout:copy>
      </xslout:template>

      <xslout:template match="*" priority="-1000" mode="#all">
        <xslout:copy>
          <xslout:namespace name="css">http://www.w3.org/1996/css</xslout:namespace>
          <xslout:apply-templates select="@* | node()" mode="#current" />
        </xslout:copy>
      </xslout:template>
      <xslout:template match="attribute() | text() | processing-instruction() | comment()" priority="-95" mode="#all">
        <xslout:copy>
          <xslout:apply-templates select="@* | node()" mode="#current" />
        </xslout:copy>
      </xslout:template>


      <xslout:template match="*[@*[matches(name(), '_important$')]]" mode="handle-important-info">
        <xslout:variable name="important-props">
          <xslout:for-each select="@*[matches(name(), '_important$')]">
            <xslout:element name="{{replace(name(), '^(.*)_important$', '$1')}}">
              <xslout:attribute name="val" select="." />
            </xslout:element>
          </xslout:for-each>
        </xslout:variable>
        <xslout:copy>
          <xslout:apply-templates select="@* except @*[contains(string-join($important-props/*/name(), ' '), name())]" mode="#current" />
          <xslout:apply-templates select="node()" mode="#current" />
        </xslout:copy>
      </xslout:template>

      <xslout:template match="@*[matches(name(), '_important$')]" mode="handle-important-info">
        <xslout:attribute name="{{replace(name(), '^(.*)_important$', '$1')}}" select="." />
      </xslout:template>

    </xslout:stylesheet>
  </xsl:template>

  <xsl:function name="tr:strip-delims" as="xs:string">
    <xsl:param name="content" as="xs:string" />
    <xsl:variable name="s1" as="xs:string" select='replace($content, "^[&#x27;](.*?)[&#x27;]$", "$1")' />
    <xsl:variable name="s2" as="xs:string" select="replace($s1, '^[&#x22;](.*?)[&#x22;]$', '$1')" />
    <xsl:variable name="result-seq" as="xs:string+">
      <xsl:analyze-string select="$s2" regex="\\([0-9A-Fa-f]{{2,5}})">
        <xsl:matching-substring>
          <xsl:sequence select="codepoints-to-string(tr:hex-to-dec(regex-group(1)))"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:sequence select="."/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:sequence select='replace(string-join($result-seq, ""), "([&#x27;])(.*?)[&#x27;]", "$1$1$2$1$1")'/>
  </xsl:function>
  
  <xsl:function name="tr:hex-to-dec" as="xs:integer">
    <xsl:param name="in" as="xs:string"/> <!-- e.g. 030C -->
    <xsl:sequence select="
      if (string-length($in) eq 1)
      then tr:hex-digit-to-integer($in)
      else 16*tr:hex-to-dec(substring($in, 1, string-length($in)-1)) +
      tr:hex-digit-to-integer(substring($in, string-length($in)))"/>
  </xsl:function>
  
  <xsl:function name="tr:hex-digit-to-integer" as="xs:integer">
    <xsl:param name="char"/>
    <xsl:sequence 
      select="string-length(substring-before('0123456789ABCDEF',
      upper-case($char)))"/>
  </xsl:function>
  
</xsl:stylesheet>