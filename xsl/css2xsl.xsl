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
  <xsl:param name="mediaquery-constraint" as="xs:string?" /><!-- e.g. 'media: screen, width: 1900px, resolution: 200pdi' or 'print' -->
  
  <xsl:output indent="yes" />
  
  <xsl:variable name="condition-inducing-pseudos" as="xs:string+"
    select="('first-child')"/>
  
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
      
      <xsl:variable name="media-contraint" select="normalize-space(tokenize($mediaquery-constraint, ',')[not(matches(.,'screen|print'))])"/>
      <xsl:variable name="matching-media-rules"
        select="for $i in $media-contraint[matches(.,'\w+')]
                return //atrule[@type='media']
                [condition[matches(@type,concat('max-',substring-before($i,':')))]
                          [xs:integer(replace(.,'px','')) &gt; xs:integer(replace(substring-after($i,':'),'px',''))]]
                [condition[matches(@type,concat('min-',substring-before($i,':')))]
                           [xs:integer(replace(.,'px','')) &lt; xs:integer(replace(substring-after($i,':'),'px','')) ] , 
                  0 &lt; xs:integer(replace(substring-after($i,':'),'px',''))]
                [1],
                //atrule[@type='media'][count(condition)=1] ">
        
      </xsl:variable>
      <xsl:for-each select="if (matches($mediaquery-constraint,'print')) 
                            then atrule[@type='print']/ruleset[declaration]/selector
                            else (ruleset[declaration]/selector , $matching-media-rules/ruleset[declaration]/selector)">
        <xsl:variable name="current-node" select="." />
        <xsl:variable name="leading-zero" as="xs:string"
          select="string-join(for $i in (string-length(@position) to 3) return '0', '')"/>
        <xslout:template match="{.}{$path-constraint}" 
          priority="{number(concat(replace(@priority, ',', ''), '.', $leading-zero, @position))}" mode="add-css-info">
          <xslout:copy>
            <xslout:apply-templates select="@*" mode="#current" />
            <xsl:variable name="is-pseudo" as="xs:boolean"
              select="exists($current-node/@pseudo[not(tokenize(., '\s+') = $condition-inducing-pseudos)])"/>
            <xsl:if test="$is-pseudo">
              <xslout:variable name="next-match" as="element(*)">
                <xslout:next-match/>
              </xslout:variable>
            </xsl:if>
            <xsl:for-each select="../declaration">
              <xsl:if test="empty($prop-constraint)
                            or
                            $prop-constraint = ''
                            or
                            tokenize($prop-constraint, '\s+') = string(@property)">
                <xslout:attribute 
                  name="{tr:prop-attr-name(.)}" 
                  select="'{  
                            if(@property eq 'content') 
                            then tr:quote-single-quotes(@value) 
                            else tr:strip-delims(@value)
                          }'" />
              </xsl:if>
            </xsl:for-each>
            <xslout:variable name="more-attributes" as="element(*)">
              <xslout:next-match/>
            </xslout:variable>
            <xslout:copy-of 
                  select="$more-attributes/@*[not(name() = ({string-join(
                                                                    for $d in $current-node/../declaration 
                                                                    return concat('''', tr:prop-attr-name($d), ''''),
                                                                    ', '
                                                                  )}))]" />
            <xslout:if test="$more-attributes/processing-instruction(fin)">
              <xslout:copy-of select="$more-attributes/node()"/>
            </xslout:if>
          </xslout:copy>
        </xslout:template>
      </xsl:for-each>

      <xslout:template match="*[@style]" mode="add-style-info">
        <xslout:variable name="style-info" as="element(*)*"><!-- css:shorthand, css:declaration -->
          <xslout:call-template name="declarations">
            <xslout:with-param name="raw-declarations" select="@style"/>
            <xslout:with-param name="origin" select="'file://internal'" tunnel="yes"/>
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

      <xslout:template match="processing-instruction(fin)" mode="add-style-info"/>

      <xslout:template match="*" priority="-1000" mode="add-style-info #default handle-important-info">
        <xslout:copy>
          <xslout:namespace name="css">http://www.w3.org/1996/css</xslout:namespace>
          <xslout:apply-templates select="@* | node()" mode="#current" />
        </xslout:copy>
      </xslout:template>
      <xslout:template match="*" priority="-1000" mode="add-css-info">
        <xslout:copy>
          <xslout:namespace name="css">http://www.w3.org/1996/css</xslout:namespace>
          <xslout:apply-templates select="@* | node()" mode="#current" />
          <xslout:processing-instruction name="fin"/>
        </xslout:copy>
      </xslout:template>
      <xslout:template match="attribute() | text() | processing-instruction() | comment()" priority="-95" mode="#all">
        <xslout:copy/>
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
  
  <xsl:function name="tr:prop-attr-name" as="xs:string">
    <xsl:param name="decl" as="element(declaration)"/>
    <xsl:variable name="sel" as="element(selector)+" select="$decl/../selector"/>
    <xsl:variable name="pseudo" as="xs:string?" 
      select="$sel/@pseudo[not(tokenize(., '\s+') = $condition-inducing-pseudos)]"/>
    <xsl:if test="count($pseudo) gt 1">
      <xsl:message terminate="yes" select="'Unsupported: Different pseudos in ', $sel"/>
    </xsl:if>
    <xsl:sequence select="concat(
                            if ($sel/@pseudo[not(tokenize(., '\s+') = $condition-inducing-pseudos)]) 
                              then concat('css:pseudo-', $sel/@pseudo, '_') 
                              else 'css:',
                            if (starts-with($decl/@property, '-'))
                              then '_' 
                              else '',
                            $decl/@property, 
                            if ($decl/@important='yes') 
                              then '_important' 
                              else ''
                          )"/>
  </xsl:function>

  <xsl:function name="tr:strip-delims" as="xs:string">
    <xsl:param name="content" as="xs:string" />
    <xsl:variable name="s1" as="xs:string" select='replace($content, "^[&#x27;](.*?)[&#x27;]$", "$1")' />
    <xsl:variable name="s2" as="xs:string" select="replace($s1, '^[&#x22;](.*?)[&#x22;]$', '$1')" />
    <xsl:variable name="result-seq" as="xs:string*">
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
  
  <xsl:function name="tr:quote-single-quotes" as="xs:string">
    <xsl:param name="content" as="xs:string" />
    <xsl:sequence select='replace($content, "([&#x27;])(.*?)[&#x27;]", "$1$1$2$1$1")'/>
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