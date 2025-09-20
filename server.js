require('dotenv').config();
const express = require("express");
const { Pool } = require("pg");
const cors = require("cors");
const path = require('path')
const fs = require('fs')
const bots = require('./bots/botexc.js');
const sqlite3 = require("sqlite3").verbose()
const util = require("./util.js");

const app = express();

app.use(cors());
app.use(express.json()); // ให้รับ JSON จาก AutoIt
app.use((req, res, next) => {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  next();
});

const appTitle = 'Pharm Q Server';
// Set the command line title
if (process.platform === 'win32') {
  process.title = appTitle;
} else {
  process.stdout.write(`\x1b]2;${appTitle}\x1b\x5c`);
}

const host = process.env.PG_HOST
const port = process.env.PG_PORT 
const user = process.env.PG_USER 
const password = process.env.PG_PASSWORD 
const database = process.env.PG_DATABASE 
// ตั้งค่าการเชื่อมต่อ PostgreSQL
const pool = new Pool({
  host: host,
  port: port,
  user: user,
  password: password,
  database: database
});

// เปิดไฟล์ database.db ในโฟลเดอร์ database/
const db = new sqlite3.Database(
  path.join(__dirname, "database", "database.db"),
  (err) => {
    if (err) console.error(err.message);
    console.log("connected to sqlite database");
  }
);

db.run(`
  CREATE TABLE IF NOT EXISTS regqueue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vn TEXT,
    hn TEXT,
    type TEXT,
    oqueue INTEGER,
    date TEXT,
    time TEXT
  )
`);

const local_port = 3076;
const local_host = '127.0.0.1'; // ตรงกับ host ที่ C++ client ส่งไป

let processing = false;       // กำลัง process /scan อยู่
let releaseNext = false;      // flag ให้หยุด delay

app.post("/scan", async (req, res) => {
  try {
    // ถ้ามี request เข้ามาแล้วกำลัง process อยู่ ให้ reject ทันที
    if (processing) {
      console.log("Scan busy, ignore this request:", req.body.code);  
      bots.botMsgBox3()    
      return res.json({ status: "busy" }); // ตอบกลับไปด้วย
    }

    processing = true;
    releaseNext = false;

    const { code } = req.body;
    if (code.length !== 9){
      console.log("invalid input value = ", code);
      processing = false;   // ปลดล็อกด้วย
      return res.json({ status: "invalid", received: code });
    }
    //console.log("Received:", code);
    const result = await pool.query(
      ` 
      WITH d1 AS (
        SELECT DISTINCT
        ovst.vn,
        ovst.hn,
        ovst.oqueue,
        CASE
        WHEN drugitems.name IS NOT NULL AND nondrugitems.name IS NOT NULL THEN 'drugcolo'
        WHEN drugitems.name IS NOT NULL AND nondrugitems.name IS NULL THEN 'drug'
        WHEN drugitems.name IS NULL AND nondrugitems.name IS NOT NULL THEN 'colo'
        ELSE 'na'
        END AS type
        --drugitems.name AS dname,
        --nondrugitems.name AS colo_name
        --ovst_doctor_sign.ovstost
        FROM ovst 
        INNER JOIN opitemrece ON opitemrece.vn = ovst.vn
        LEFT JOIN drugitems ON drugitems.icode = opitemrece.icode
        LEFT JOIN nondrugitems ON nondrugitems.icode = opitemrece.icode 
        AND nondrugitems.icode IN ('3004683', '3004699', '3004700', '3004701', '3004684', '3004702')
        LEFT JOIN ovst_doctor_sign ON ovst_doctor_sign.vn = ovst.vn
        WHERE
        ovst.hn = '${code}'
        AND ovst.vstdate = CURRENT_DATE
        AND (drugitems.name IS NOT NULL OR nondrugitems.name IS NOT NULL)
        AND (ovst.finance_lock IS NULL OR ovst.finance_lock = 'N')
        AND ovst_doctor_sign.ovstost NOT IN ('06','55')
        
        ORDER BY ovst.vn DESC, ovst.oqueue DESC
        LIMIT 3
      )
      SELECT * FROM d1 

      `
    );
    
    let delay = 100;
    if(result.rows.length > 0){
      console.log(`HN: ${code}, result: `,result.rows); 
      //bots.botMsgBox2()
      delay = 20000;
      const data = result.rows[0]      
      const d = new Date();
      const dateStr = util.formatDateStr(d)
      const h = util.addZero(d.getHours());
      const m = util.addZero(d.getMinutes());
      const s = util.addZero(d.getSeconds());
      const timeStr = h + ":" + m + ":" + s;
      const sql = `INSERT INTO regqueue (vn, hn, type, oqueue, date, time) VALUES (?, ?, ?, ?, ?, ?)`
      db.run(sql, [data.vn, data.hn, data.type, data.oqueue, dateStr, timeStr], (err) => {
        if (err) {
          console.error(err.message);
          return;
        }
        console.log(`HN: ${data.hn}, queue: ${data.oqueue} record success`);
      });
      
      fs.writeFileSync(path.join(__dirname,'bots/queue.txt'),data.oqueue.toString()) 
      bots.botQueue()
      res.json({ status: "ok", received: code });
    }
    else{      
      bots.botMsgBox1()
      delay = 2000;
      console.log("no result from HN: ", code); 
      res.json({ status: "notfound", received: code });
    }    
    
    let waited = 0;    
    const interval = 100;
    while (waited < delay && !releaseNext) {
      await new Promise(r => setTimeout(r, interval));
      waited += interval;
    }

    processing = false; // ปลดให้ request ต่อไป process ได้
  } catch (err) {
    console.error(err);
    processing = false;
    releaseNext = false;
    res.status(500).json({ status: "error", message: err.message });
  }
});

app.post("/complete", (req, res) => {
  releaseNext = true;
  console.log("Release next request immediately due to /complete");
  res.json({ status: "complete" });
});

app.post("/financelock", (req, res) => {
  releaseNext = true;
  console.log("Release next request immediately due to /financelock");
  res.json({ status: "complete with finance locked" });
});

app.listen(local_port, local_host, () => {
  console.log(`Server listening on ${local_host}:${local_port}`);
});
