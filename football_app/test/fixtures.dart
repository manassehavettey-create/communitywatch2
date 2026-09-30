/// Recorded-shape API-Football v3 payloads used by the data-layer tests.
const fixtureDetailJson = r'''
{"get":"fixtures","parameters":{"id":"1001"},"errors":[],"results":1,"paging":{"current":1,"total":1},
"response":[{
 "fixture":{"id":1001,"referee":"M. Oliver","timezone":"UTC","date":"2026-09-30T19:00:00+00:00","timestamp":1790794800,
   "venue":{"id":556,"name":"Emirates Stadium","city":"London"},"status":{"long":"Second Half","short":"2H","elapsed":78,"extra":null}},
 "league":{"id":39,"name":"Premier League","country":"England","logo":"https://x/39.png","flag":"https://x/gb.svg","season":2026,"round":"Regular Season - 8"},
 "teams":{"home":{"id":42,"name":"Arsenal","logo":"https://x/42.png","winner":true},"away":{"id":49,"name":"Chelsea","logo":"https://x/49.png","winner":false}},
 "goals":{"home":2,"away":1},
 "score":{"halftime":{"home":1,"away":0},"fulltime":{"home":null,"away":null},"extratime":{"home":null,"away":null},"penalty":{"home":null,"away":null}},
 "events":[
  {"time":{"elapsed":42,"extra":null},"team":{"id":42},"player":{"id":7,"name":"B. Saka"},"assist":{"id":8,"name":"M. Odegaard"},"type":"Goal","detail":"Normal Goal","comments":null},
  {"time":{"elapsed":53,"extra":null},"team":{"id":49},"player":{"id":20,"name":"C. Palmer"},"assist":{"id":null,"name":null},"type":"Goal","detail":"Penalty","comments":null},
  {"time":{"elapsed":61,"extra":null},"team":{"id":42},"player":{"id":29,"name":"K. Havertz"},"assist":{"id":null,"name":null},"type":"Goal","detail":"Normal Goal","comments":null},
  {"time":{"elapsed":68,"extra":null},"team":{"id":42},"player":{"id":41,"name":"D. Rice"},"assist":{"id":null,"name":null},"type":"Card","detail":"Yellow Card","comments":"Foul"},
  {"time":{"elapsed":74,"extra":null},"team":{"id":42},"player":{"id":19,"name":"L. Trossard"},"assist":{"id":11,"name":"G. Martinelli"},"type":"subst","detail":"Substitution 1","comments":null}
 ],
 "lineups":[
  {"team":{"id":42,"name":"Arsenal","logo":"https://x/42.png","colors":{"player":{"primary":"ff0000","number":"ffffff","border":"ff0000"}}},"formation":"4-3-3",
   "startXI":[{"player":{"id":1,"name":"D. Raya","number":22,"pos":"G","grid":"1:1"}},{"player":{"id":7,"name":"B. Saka","number":7,"pos":"F","grid":"4:3"}},{"player":{"id":19,"name":"L. Trossard","number":19,"pos":"F","grid":"4:1"}}],
   "substitutes":[{"player":{"id":11,"name":"G. Martinelli","number":11,"pos":"F","grid":null}}],"coach":{"id":1,"name":"M. Arteta"}},
  {"team":{"id":49,"name":"Chelsea","logo":"https://x/49.png","colors":null},"formation":"4-2-3-1",
   "startXI":[{"player":{"id":20,"name":"C. Palmer","number":20,"pos":"M","grid":"4:2"}}],"substitutes":[],"coach":{"id":2,"name":"E. Maresca"}}
 ],
 "statistics":[
  {"team":{"id":42},"statistics":[{"type":"Ball Possession","value":"54%"},{"type":"Total Shots","value":15},{"type":"Red Cards","value":null},{"type":"expected_goals","value":"1.72"},{"type":"Passes %","value":"86%"}]},
  {"team":{"id":49},"statistics":[{"type":"Ball Possession","value":"46%"},{"type":"Total Shots","value":9},{"type":"Red Cards","value":null},{"type":"expected_goals","value":"0.94"},{"type":"Passes %","value":"81%"}]}
 ],
 "players":[
  {"team":{"id":42},"players":[{"player":{"id":7,"name":"B. Saka","photo":"https://x/p7.png"},"statistics":[{"games":{"minutes":78,"number":7,"position":"F","rating":"8.2","captain":false,"substitute":false},
    "shots":{"total":3,"on":2},"goals":{"total":1,"conceded":0,"assists":0,"saves":null},"passes":{"total":30,"key":2,"accuracy":"24"},"tackles":{"total":1,"blocks":null,"interceptions":2},
    "duels":{"total":8,"won":6},"dribbles":{"attempts":5,"success":4,"past":null},"fouls":{"drawn":2,"committed":1},"cards":{"yellow":0,"red":0},"penalty":{"won":null,"commited":null,"scored":0,"missed":0,"saved":null}}]}]},
  {"team":{"id":49},"players":[{"player":{"id":20,"name":"C. Palmer","photo":null},"statistics":[{"games":{"minutes":78,"number":20,"position":"M","rating":"7.1","captain":true,"substitute":false},
    "shots":{"total":2,"on":1},"goals":{"total":1,"conceded":0,"assists":null,"saves":null},"passes":{"total":40,"key":1,"accuracy":"33"},"tackles":{"total":null,"blocks":null,"interceptions":null},
    "duels":{"total":4,"won":2},"dribbles":{"attempts":1,"success":1,"past":null},"fouls":{"drawn":1,"committed":0},"cards":{"yellow":0,"red":0},"penalty":{"won":null,"commited":null,"scored":1,"missed":0,"saved":null}}]}]}
 ]
}]}
''';

const standingsJson = r'''
{"errors":[],"response":[{"league":{"id":39,"name":"Premier League","country":"England","logo":null,"flag":null,"season":2026,"standings":[[
 {"rank":1,"team":{"id":42,"name":"Arsenal","logo":null},"points":19,"goalsDiff":11,"group":"Premier League","form":"WWDWW","status":"up","description":"Promotion - Champions League (League phase)","all":{"played":8,"win":6,"draw":1,"lose":1,"goals":{"for":17,"against":6}}},
 {"rank":18,"team":{"id":99,"name":"Burnley","logo":null},"points":5,"goalsDiff":-9,"group":"Premier League","form":"LLDLW","status":"down","description":"Relegation - Championship","all":{"played":8,"win":1,"draw":2,"lose":5,"goals":{"for":6,"against":15}}}
]]}}]}
''';

const planErrorJson = r'''{"get":"standings","errors":{"plan":"Free plans do not have access to this season, try from 2021 to 2023."},"results":0,"response":[]}''';
const tokenErrorJson = r'''{"errors":{"token":"Error/Missing application key."},"response":[]}''';
