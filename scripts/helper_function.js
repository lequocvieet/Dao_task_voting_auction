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
const POLL_STATE = {
  CREATED: 0,
  OPENFORVOTE: 1,
  VOTED: 2,
};

// const BATCH_TASK_STATE = {
//   CREATED: 0,
//   VOTED: 1,
//   OPENFORAUCTION: 2,
//   ENDAUCTION: 3,
// };

// const TASK_STATE = {
//   CREATED: 0,
//   ASSIGNED: 1,
//   OPENFORAUCTION: 2,
//   RECEIVED: 3,
//   SUBMITTED: 4,
//   REVIEWED: 5,
// };

// module.exports.GetEnumValueByIndex = function (enumType, index) {
//   console.log(index);
//   let enumValues;
//   switch (enumType) {
//     case POLL_STATE:
//       enumValues = Object.values(POLL_STATE);
//       break;
//     case BATCH_TASK_STATE:
//       enumValues = Object.values(BATCH_TASK_STATE);
//       break;
//     case TASK_STATE:
//       enumValues = Object.values(TASK_STATE);
//       break;
//     default:
//   }
//   const enumValueAtIndex = enumValues[1];
//   return enumValueAtIndex;
// };
