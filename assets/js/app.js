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

function compute_token_clicked_payload(token_id, clientX, clientY) {
  const board = document.getElementById("board");
  const boundingRect = board.getBoundingClientRect();
  const browserX = clientX - boundingRect.x;
  const browserY = clientY - boundingRect.y;
  return {
    target: token_id,
    x: (browserX / boundingRect.width) * 100,
    y: 100 - (browserY / boundingRect.height) * 100 // przeglądara liczy y od góry a nie od dołu
  };
}

let Hooks = {}
Hooks.PanzoomHook = {
  mounted() {
    const push_event = (event, payload) => this.pushEvent(event, payload);
    window[`panzoom_${this.el.id}`] = panzoom(this.el, {
      zoomDoubleClickSpeed: 1,
      onTouch: function (touchEvent) {
        const touch = touchEvent.targetTouches[0];
        const token_id = touch.target.id.substring("token_image_".length);
        push_event("token_clicked", compute_token_clicked_payload(token_id, touch.clientX, touch.clientY))
        return true;
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
