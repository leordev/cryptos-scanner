import "phoenix_html"
import { Socket } from "phoenix"

require('bulma');

const STORAGE_KEY = "CTB_USER";

const storageBody = localStorage.getItem(STORAGE_KEY);
const flags = !storageBody ?
  { user: {
    id: "TODO: FIX",
    email: "",
    name: "",
    apiKey: "TODO: FIX",
    apiSecret: "TODO: FIX",
    apiChannelKey: "TODO: FIX"
    },
    exchanges: []
  } : JSON.parse(storageBody)

const Elm = require("../elm/Main");
const app = Elm.Main.fullscreen(flags);

app.ports.saveUser.subscribe(function(user){
  const data = { user: user, exchanges: [] }
  console.log("saving user data ", data)
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
});

app.ports.saveExchanges.subscribe(function(flags){
  console.log("saving exchange setup data ", flags)
  localStorage.setItem(STORAGE_KEY, JSON.stringify(flags));

  startSockets(flags);
});

app.ports.deleteUser.subscribe(function(){
  localStorage.removeItem(STORAGE_KEY);
});

app.ports.setTitle.subscribe(function(title) {
  if (document.title != title) {
      document.title = title;
  }
})

// app.ports.setFilter.subscribe(filter => {
//   console.log("Setting filter >>>>> ", filter)
//   channel.push("set_filter", filter)
// })

// app ports for elm and/or business logic
const socket = new Socket("/socket")
socket.connect()

// Now that you are connected, you can join channels with a topic:
const channel = socket.channel("scanner:alerts", {})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully") })
  .receive("error", resp => { console.log("Unable to join", resp) })

channel.push("set_filter", { period: "5m", percentage: -4})

channel.on("tick_alert", payload => {
  const coins = payload.coins.map(c => {
    return Object.assign({}, c, {
      marketId: c.exchange + "-" + c.symbol,
      market: c.symbol,
      volume: Number.parseFloat(c.volume),
      btcVolume: Number.parseFloat(c.volume),
      bidPrice: Number.parseFloat(c.bidPrice),
      askPrice: Number.parseFloat(c.askPrice),
      lastPrice: Number.parseFloat(c.lastPrice || 0),
      percentage: Number.parseFloat(c.percentage.toFixed(2)),
      time: (new Date).toString()
    })
  })
  app.ports.newAlert.send(coins)
})
