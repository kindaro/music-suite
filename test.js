
var score = null;

function reload() {
    var fs = require('fs');
    var txt = fs.readFileSync('test.json', 'utf8');
    score = JSON.parse(txt);    
}


/*

console.log(score.staves[0].bars[0]);

*/