function formatDateStr(d){  
   const dd = d.getDate() > 9 ? d.getDate() : "0"+ d.getDate()
   const mm = d.getMonth() + 1 > 9 ? d.getMonth() + 1 : "0" + (d.getMonth() + 1)
   const yyyy = d.getUTCFullYear()
   const dateStr = yyyy +"-"+ mm +"-"+ dd
   return dateStr
}

function addZero(i) {
  if (i < 10) {i = "0" + i}
  return i;
}

module.exports.formatDateStr = formatDateStr
module.exports.addZero = addZero