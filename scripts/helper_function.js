module.exports.EpochTimeToDate = function (epochTime) {
  let today = new Date(epochTime * 1000);
  let time =
    today.toDateString().slice(4) +
    " " +
    today.getHours() +
    ":" +
    today.getMinutes();
  return time;
};
