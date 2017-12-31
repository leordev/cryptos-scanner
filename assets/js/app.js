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

// app.ports.setFilter.subscribe(filter => {
//   console.log(">>>>> Setting filter ", filter)
//   // channel.push("set_filter", filter)
// })
