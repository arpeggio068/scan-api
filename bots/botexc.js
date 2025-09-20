const exec = require('child_process').exec
const path = require('path')

function exec_Fl(str){
    const process = exec(str, (err, stdout, stderr) => {
        if (err) {
            console.log(stderr);
            return;
        }
        // Done.
        console.log(stdout);
    });
}

function botQueue(){
   exec_Fl(path.join(__dirname,'botProcessing.exe'))   
}

function botMsgBox1(){
    exec_Fl(path.join(__dirname,'botNoList.exe'))   
}

function botMsgBox2(){
    exec_Fl(path.join(__dirname,'botFoundList.exe'))   
}

function botMsgBox3(){
    exec_Fl(path.join(__dirname,'botBusy.exe'))   
}

module.exports.botQueue = botQueue
module.exports.botMsgBox1 = botMsgBox1
module.exports.botMsgBox2 = botMsgBox2
module.exports.botMsgBox3 = botMsgBox3




