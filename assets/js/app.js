// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import "../rpgui/rpgui"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}
Hooks.PanzoomHook = {
  mounted() {
    window[`panzoom_${this.el.id}`] = panzoom(this.el, {
      onTouch: function (touchEvent) {
        return false; // tells the library to not preventDefault.
      }
    });

  },
  beforeUpdate() {
    window[`panzoom_${this.el.id}`].pause();
  },
  updated() {
    window[`panzoom_${this.el.id}`].resume();
  }
}

Hooks.BoardToken = {
  mounted() {
    const token_id = this.el.id.substring("token_".length);
    this.el.addEventListener("touchend", (event) => {
      var board = document.getElementById("board");
      if (board) {
        var boundingRect = board.getBoundingClientRect();
        var browserX = e.clientX - boundingRect.x;
        var browserY = e.clientY - boundingRect.y;
        pushEvent("token_clicked", {
          id: token_id,
          x: (browserX / boundingRect.width) * 100,
          y: 100 - (browserY / boundingRect.height) * 100 // przeglądara liczy y od góry a nie od dołu
        });
      }
    });
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  metadata: {
    click: (e, el) => {
      // var boundingRect = el.getBoundingClientRect();
      var board = document.getElementById("board");
      if (board) {
        var boundingRect = board.getBoundingClientRect();
        var browserX = e.clientX - boundingRect.x;
        var browserY = e.clientY - boundingRect.y;
        return {
          x: (browserX / boundingRect.width) * 100,
          y: 100 - (browserY / boundingRect.height) * 100 // przeglądara liczy y od góry a nie od dołu
        };
      } else {
        return {};
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
