// @davidberneda
// 2017
unit TeePEG_Grammar;

{
  "Parsing Expression Grammars" (PEG)

  Implementation for: Mr. Bryan Ford baford@mit.edu
  http://bford.info/pub/lang/peg.pdf
}

interface

uses
  TeePEG_Rules;

type
  TGrammar=class(TPrioritized)
  private
    FParser : TParser;

    function Load:TGrammar; overload;
  public
    Constructor Create;
    Destructor Destroy; override;

    procedure Add(const ARule:TRule);
    function AsString:String; override;

    class function From(const AItem:PSyntaxItem):TGrammar; static;

    function Load(const S:String):TGrammar; overload;

    property Parser:TParser read FParser;
  end;

  TPEGGrammar=class(TGrammar)
  public
    Constructor Create;
  end;

implementation

uses
  SysUtils;

{ TGrammar }

Constructor TGrammar.Create;
begin
  inherited Create([]);
  FParser:=TParser.Create;
end;

Destructor TGrammar.Destroy;
var t : Integer;
begin
  for t:=Low(Items) to High(Items) do
      Items[t].Free;

  FParser.Free;
  inherited;
end;

class function TGrammar.From(const AItem: PSyntaxItem): TGrammar;
begin
  result:=TGrammar.Create;
end;

function TGrammar.AsString: String;
const
  LeftArrow=' <- ';

var t : Integer;
begin
  result:='';

  for t:=0 to High(Items) do
  begin
    if t>0 then
       result:=result+#13#10;

    if Items[t] is TNamedRule then
    begin
      result:=result+TNamedRule(Items[t]).Name;
      result:=result+LeftArrow+TOperator(Items[t]).Rule.AsString;
    end
    else
      result:=result+'Error:'+LeftArrow+Items[t].AsString;
  end;
end;

function TGrammar.Load(const S: String):TGrammar;
begin
  FParser.Start(S);
  result:=Load;
end;

function TGrammar.Load:TGrammar;
var
  Start : Integer;

  procedure DoError(const S:String);
  begin
    raise Exception.Create(S+' At: '+IntToStr(Start));
  end;

var tmp : PSyntaxItem;
begin
  result:=nil;

  FParser.Position:=1;

  repeat
    Start:=FParser.Position;

    tmp:=Match(FParser);

    if tmp=nil then
       DoError('Invalid syntax')
    else
    if FParser.Position=Start then
       DoError('Infinite loop')
    else
    if tmp.Rule is TGrammar then
    begin
      FParser.Syntax:=tmp;
      result:=TGrammar.From(tmp);
      Exit;
    end
    else
      DoError('Grammar expected. Found: '+tmp.Rule.ClassName);

  until FParser.EndOfFile;
end;

procedure TGrammar.Add(const ARule: TRule);
var L : Integer;
begin
  L:=Length(Items);
  SetLength(Items,L+1);
  Items[L]:=ARule;
end;

{ TPEGGrammar }

Constructor TPEGGrammar.Create;
var EndOfFile,
    AnyCharacter,
    LineFeed,
    EndOfLine,
    Space,
    Comment,
    SpaceOrComment,
    Spacing,
    NeedsSpacing,
    DOT, CLOSE, OPEN, PLUS, STAR, QUESTION, _NOT, _AND, SLASH, LEFTARROW,

    CharRule, Range, ClassRule,

    Literal, IdentCont, IdentStart, Identifier,

    Primary, Suffix, Prefix, Sequence, Expression, Definition, Grammar

     : TRule;

    Tab,
    Return,
    NewLine,
    BackSlash,
    LeftBracket,
    RightBracket : TCharacter;

  procedure Add(const ARule:TRule);
  var L : Integer;
  begin
    L:=Length(Items);
    SetLength(Items,L+1);
    Items[L]:=ARule;
  end;

  procedure AddRules;
  begin
    Add(Grammar);
    Add(Definition);

    Add(Expression);
    Add(Sequence);
    Add(Prefix);
    Add(Suffix);
    Add(Primary);
    Add(Identifier);
    Add(IdentStart);
    Add(IdentCont);
    Add(Literal);
    Add(ClassRule);
    Add(Range);
    Add(CharRule);

    Add(DOT);
    Add(CLOSE);
    Add(OPEN);
    Add(PLUS);
    Add(STAR);
    Add(QUESTION);
    Add(_NOT);
    Add(_AND);
    Add(SLASH);
    Add(LEFTARROW);

    Add(NeedsSpacing);
    Add(Spacing);
    Add(SpaceOrComment);
    Add(Comment);
    Add(Space);
    Add(EndOfLine);
    Add(EndOfFile);
  end;

  function CharSpacing(const AName:String; const AChar:Char):TRule;
  begin
    result:=TNamedRule.Create(AName,TSequence.Create([TCharacter.Create(AChar),Spacing]));
  end;

var
  Escapable : TCharacterSet;
  ParentExpression : TSequence;

begin
  inherited;

  AnyCharacter:=TAnyCharacter.Create;

  EndOfFile:=TNamedRule.Create('EndOfFile',TNotPredicate.Create(AnyCharacter));

  Return:=TCharacter.Create(#13);
  NewLine:=TCharacter.Create(#10);
  Tab:=TCharacter.Create(#9);
  LineFeed:=TString.Create(#13#10);

  EndOfLine:=TNamedRule.Create('EndOfLine',TPrioritized.Create([LineFeed,NewLine,Return]));

  Space:=TNamedRule.Create('Space',TPrioritized.Create([TCharacter.Create(' '),
                              Tab,
                              EndOfLine])
              );

  Comment:=TNamedRule.Create('Comment',
           TSequence.Create([TCharacter.Create('#'),
                             TZeroOrMore.Create(
                                 TSequence.Create(
                                      [ TNotPredicate.Create(EndOfLine),
                                        AnyCharacter ])
                             ),
                             TPrioritized.Create([
                                EndOfLine,
                                EndOfFile
                                ])
                             ])
              );

  SpaceOrComment:=TNamedRule.Create('SpaceOrComment',TPrioritized.Create([Space,Comment]));

  Spacing:=TNamedRule.Create('Spacing',TZeroOrMore.Create(SpaceOrComment));

  NeedsSpacing:=TNamedRule.Create('NeedsSpacing',TOneOrMore.Create(SpaceOrComment));

  DOT:=CharSpacing('DOT','.');
  CLOSE:=CharSpacing('CLOSE',')');
  OPEN:=CharSpacing('OPEN','(');
  PLUS:=CharSpacing('PLUS','+');
  STAR:=CharSpacing('STAR','*');
  QUESTION:=CharSpacing('QUESTION','?');
  _NOT:=CharSpacing('NOT','!');
  _AND:=CharSpacing('AND','&');
  SLASH:=CharSpacing('SLASH','/');

  LEFTARROW:=TNamedRule.Create('LEFTARROW',TSequence.Create([TString.Create('<-'),Spacing]));

  BackSlash:=TCharacter.Create('\');
  LeftBracket:=TCharacter.Create('[');
  RightBracket:=TCharacter.Create(']');

  Escapable:=TCharacterSet.Create([
               TCharacter.Create('n'),
               TCharacter.Create('r'),
               TCharacter.Create('t'),
               TCharacter.Create(SingleQuote.Character),
               TCharacter.Create(DoubleQuote.Character),
               TCharacter.Create(LeftBracket.Character),
               TCharacter.Create(RightBracket.Character),
               TCharacter.Create(BackSlash.Character)
             ]);

  CharRule:=TNamedRule.Create('Char',
                TPrioritized.Create([
                                   TSequence.Create([ BackSlash, Escapable ]),

                                   TSequence.Create([ BackSlash,
                                                      TCharacterRange.Create('0','2'),
                                                      TCharacterRange.Create('0','7'),
                                                      TCharacterRange.Create('0','7') ]),

                                   TSequence.Create([ BackSlash,
                                                      TCharacterRange.Create('0','7'),
                                                      TOptional.Create(
                                                        TCharacterRange.Create('0','7')
                                                      )
                                                    ]),
                                   TSequence.Create([ TNotPredicate.Create(BackSlash), AnyCharacter ])

                                ])
                );

  Range:=TNamedRule.Create('Range',
           TPrioritized.Create([
               TSequence.Create([ CharRule, TCharacter.Create('-'), CharRule ]),
               CharRule
            ])
           );

  ClassRule:=TNamedRule.Create('Class',
               TSequence.Create([
                 LeftBracket,
                 TZeroOrMore.Create(
                    TSequence.Create(
                        [ TNotPredicate.Create(RightBracket), Range ]
                      )
                 ),
                 RightBracket,
                 Spacing
               ])
              );

  Literal:=TNamedRule.Create('Literal',
             TPrioritized.Create([
               TSequence.Create([
                       SingleQuote,
                       TZeroOrMore.Create(
                            TSequence.Create([
                                TNotPredicate.Create(SingleQuote),
                                CharRule
                              ])
                          ),
                       SingleQuote,
                       Spacing
                    ]),
               TSequence.Create([
                       DoubleQuote,
                       TZeroOrMore.Create(
                            TSequence.Create([
                                TNotPredicate.Create(DoubleQuote),
                                CharRule
                              ])
                          ),
                       DoubleQuote,
                       Spacing
                    ])
             ])
           );

  IdentStart:=TNamedRule.Create('IdentStart',
                TCharacterSet.Create([
                 TCharacterRange.Create('a','z'),
                 TCharacterRange.Create('A','Z'),
                 TCharacter.Create('_')
                 ])
              );

  IdentCont:=TNamedRule.Create('IdentCont',
                TPrioritized.Create([
                     IdentStart,
                     TCharacterRange.Create('0','9')
                  ])
                );

  Identifier:=TNamedRule.Create('Identifier',
                TSequence.Create([
                  IdentStart,
                  TZeroOrMore.Create(IdentCont),
                  Spacing
                ])
              );

  ParentExpression:=TSequence.Create([OPEN, Expression, CLOSE] );

  Primary:=TNamedRule.Create('Primary',
              TPrioritized.Create([
                 TSequence.Create([ Identifier, TNotPredicate.Create(LEFTARROW) ]),
                 ParentExpression,
                 Literal,
                 ClassRule,
                 DOT
              ])
            );

  Suffix:=TNamedRule.Create('Suffix',
            TSequence.Create([
              Primary,
              TOptional.Create(
                TPrioritized.Create([
                     QUESTION,
                     STAR,
                     PLUS
                   ])
                )
            ])
          );

  Prefix:=TNamedRule.Create('Prefix',
            TSequence.Create([
              TOptional.Create( TPrioritized.Create([ _AND, _NOT ]) ),
              Suffix
            ])
          );

  Sequence:=TNamedRule.Create('Sequence',
               TSequence.Create([
                 Prefix,
                 TZeroOrMore.Create(Prefix)
               ])
             );

  Expression:=TNamedRule.Create('Expression',
               TSequence.Create([
                 Sequence,
                 TZeroOrMore.Create(
                    TSequence.Create([
                         SLASH, Sequence
                       ])
                   )
               ])
              );

  // Re-link "Expression"
  ParentExpression.Items[1]:=Expression;

  Definition:=TNamedRule.Create('Definition',
                 TSequence.Create([ Identifier, LEFTARROW, Expression ]));

  Grammar:=TNamedRule.Create('Grammar',
            TSequence.Create([
               Spacing,
               TOneOrMore.Create(Definition),
               EndOfFile
             ])
            );

  AddRules;
end;

end.
