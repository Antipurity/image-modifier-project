module ImageModifierProject

using Sockets
using HTTP



mutable struct Image
  width::Int
  height::Int
  data::Array{UInt8,2}
end
Image(w,h) = Image(w, h, zeros(UInt8, w, h))



function imgToStr(img::Image, x::Int=0, y::Int=0, w::Int=img.width, h::Int=img.height)
  data = join(vec(string.(img.data[1+x : x+w, 1+y : y+h], base=16))) # Column-major.
  return string(x, " ", y, " ", w, " ", h, " ", data)
end



const editorHtml = """
<!DOCTYPE html>
<html lang=en>
<head>
  <meta charset=utf-8>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
<!-- Oh boy, I sure hope no one overwhelms the server and/or draws offensive imagery. -->
<div id=color_selection></div>
<canvas id=main></canvas>
<script>
const colors = [
  0x000000,
  0x800000,
  0x008000,
  0x808000,
  0x000080,
  0x800080,
  0x008080,
  0xc0c0c0,
  0x808080,
  0xff0000,
  0x00ff00,
  0xffff00,
  0x0000ff,
  0xff00ff,
  0x00ffff,
  0xffffff,
].reverse()
// Create colors for the color selection.
let selectedColor = 0
for (let i = 0; i < colors.length; ++i) {
  const el = document.createElement('div')
  el.className = 'color'
  if (i === selectedColor) el.classList.add('selected')
  el.style.backgroundColor = '#' + padStart(colors[i].toString(16), 6, '0')
  el.onclick = evt => {
    selectedColor = i
    ;[...document.getElementsByClassName('selected')].forEach(e => e.classList.remove('selected'))
    el.classList.add('selected')
  }
  if (i && !(i % 8)) {
    const wrap = document.createElement('div')
    wrap.className = 'break'
    document.getElementById('color_selection').appendChild(wrap)
  }
  document.getElementById('color_selection').appendChild(el)
}



let pixelW = 0, pixelH = 0, pixels = null // Pixel data here.
let socket = null
function getWSAddress() {
  const we = new URL('image', ''+location)
  const protocol = we.protocol === 'https:' ? 'wss:' : 'ws:'
  we.protocol = protocol
  return ''+we
}
setTimeout(() => {
  socket = new WebSocket(getWSAddress('wss:'))
  socket.onmessage = evt => {
    // Decode x&y&w&h&data, resize `pixels` if needed, and put pixels.
    socket.onerror = null
    let [x, y, w, h, data] = evt.data.split(' ')
    x=+x, y=+y, w=+w, h=+h
    if (!w || !h || !data) return
    if (!pixels || pixels.length < (x+w) * (y+h)) {
      pixelW = x+w, pixelH = y+h, pixels = new Uint8Array(pixelW * pixelH)
      smallCtx.canvas.width = pixelW, smallCtx.canvas.height = pixelH
    }
    update(x, y, w, h, data)
  }
}, 0)



const canvas = document.getElementById('main')
const ctx = canvas.getContext('2d', {alpha:false, desynchronized:true})
let dragStart = null
canvas.onpointerdown = evt => {
  const x = evt.clientX, y = evt.clientY, id = evt.pointerId // No scroll, so no need to offset these.
  dragStart = { x, y, id, moved:0 }
  canvas.setPointerCapture(id)
}
canvas.onpointermove = evt => {
  if (!dragStart || evt.pointerId !== dragStart.id) return
  const x = evt.clientX, y = evt.clientY, id = evt.pointerId
  const dx = x - dragStart.x, dy = y - dragStart.y
  dragStart.x = x, dragStart.y = y
  dragStart.moved += Math.abs(dx) + Math.abs(dy)
  canvasOffsetX += dx, canvasOffsetY += dy, redraw()
}
canvas.onpointerup = evt => {
  if (socket && socket.readyState === 1 && pixels && (!dragStart || dragStart.moved < 10)) {
    const x = evt.clientX, y = evt.clientY, id = evt.pointerId
    const pixPos = canvasToPixels(x,y)
    update(pixPos[0], pixPos[1], 1, 1, (selectedColor ^ 8).toString(16))
    socket.send(`\${pixPos[0]} \${pixPos[1]} \${selectedColor}`)
  }
  dragStart && canvas.releasePointerCapture(dragStart.id)
  dragStart = null
}
window.onwheel = evt => {
  const add = evt.deltaY / 10
  const scale2 = Math.max(2, Math.min(scale + add, 64))
  const x = evt.clientX - canvasOffsetX, y = evt.clientY - canvasOffsetY
  const dx = x*scale2/scale - x, dy = y*scale2/scale - y
  canvasOffsetX -= dx, canvasOffsetY -= dy
  scale = scale2
  redraw()
}
let canvasOffsetX = 0, canvasOffsetY = 0 // Draggable canvas offsets here.
let scale = 16

window.onload = window.onresize = setCanvasSize

const smallCtx = document.createElement('canvas').getContext('2d', {alpha:false, desynchronized:true})
function setCanvasSize() {
  canvas.width = document.body.clientWidth
  canvas.height = document.body.clientHeight
  redraw()
}
function canvasToPixels(x,y) {
  return [Math.floor((x - canvasOffsetX) / scale), Math.floor((y - canvasOffsetY) / scale)]
}
function update(x, y, w, h, data) {
  // Updates both `pixels` and `smallCtx`.
  const img = smallCtx.createImageData(w, h)
  for (let i = 0; i < img.data.length; i += 4) {
    const dx = Math.floor(i/4) % w, dy = Math.floor(Math.floor(i/4) / w) // Row-major.
    const sx = x + dx, sy = y + dy
    const ok = sx >= 0 && sy >= 0 && sx < pixelW && sy < pixelH
    // `pixels` are column-major.
    const color = ok ? colors[pixels[sx*pixelH + sy] = parseInt(data[i/4 | 0], 16)] : 0
    img.data[i+0] = ok ? color>>>16 : (sx+sy)%2 ? 64 : 0
    img.data[i+1] = ok ? (color>>>8)&255 : 0
    img.data[i+2] = ok ? color&255 : (sx+sy)%2 ? 64 : 0
    img.data[i+3] = 255
  }
  smallCtx.putImageData(img, x, y)
  redraw()
}
function redraw() {
  if (!pixels) return
  const x1 = canvasOffsetX | 0, x2 = x1 + pixelW * scale | 0
  const y1 = canvasOffsetY | 0, y2 = y1 + pixelH * scale | 0
  ctx.imageSmoothingEnabled = false
  ctx.clearRect(0, 0, canvas.width, canvas.height)
  ctx.drawImage(smallCtx.canvas, 0, 0, pixelW, pixelH, x1, y1, x2-x1, y2-y1)
}



function repeat(str, n) {
  let result = ''
  for (let i = 0; i < n; ++i) result += str
  return result
}
function padStart(str, targetLength, padString) {
  if (str.length > targetLength) return str
  targetLength = targetLength - str.length
  if (targetLength > padString.length)
    padString += repeat(padString, targetLength / padString.length >>> 0)
  return padString.slice(0, targetLength) + str
}
</script>
<style>
* { transition: all .2s }
html, body { margin: 0;  width: 100%;  height: 100%;  overflow: hidden; }
#color_selection {
  display: flex;
  flex-flow: wrap;
  position: absolute;
}
#color_selection>div.break { width: 100%; }
div.color {
  width: 2em;
  height: 2em;
  border-radius: 50%;
  border: .1em solid;
  border-color: white;
  box-shadow: 0 0 .3em;
  margin: .2em;
}
div.color:hover { border-color: #9e9e9e; }
div.color.selected { border-color: #2196f3;  box-shadow: 0 0 1em blue; }
div.color.selected:hover { border-color: #03a9f4; }
</style>
</body>
</html>
"""



function __init__() # Ah yes, execute non-__init__ code during pre-compilation.
  args = ARGS
  push!(args, "8081")
  if size(args)[1] < 1
    throw("Too few args; expected the port")
  end
  server = Sockets.listen(Sockets.InetAddr("0.0.0.0", parse(Int64, args[1])))



  scratchpad = Image(500, 500) # No DB integration for now.
  connections = []
  HTTP.serve(server=server; stream=true) do stream::HTTP.Stream
    if stream.message.target == "/"
      write(stream, editorHtml)
      stream.message.response.status = 200
    elseif stream.message.target == "/image"
      # Set up a WebSocket: send image & updates, receive updates.
      stream.message.response.status = 200
      HTTP.WebSockets.upgrade(stream) do ws
        # Send the whole image, then receive one-pixel updates unless they are too fast.
        img = scratchpad
        push!(connections, ws)
        write(ws, imgToStr(img) * "\n\n")
        last_update = time()
        try
          while !eof(ws)
            data = String(readavailable(ws)) # Still don't know if it's one-read-per-message, or shitty.
            values = map(x -> tryparse(Int64, x), split(strip(data), " "))
            if size(values)[1] != 3
              continue
            end
            x, y, value = values
            if x < 0 || y < 0 || value < 0 || x >= img.width || y >= img.height || value >= 16
              continue
            end
            new_update = time()
            if new_update - last_update > .5
              # Update and broadcast, at most once per second.
              img.data[x+1, y+1] = value
              update_msg = string(imgToStr(img, x, y, 1, 1))
              for conn in connections
                write(conn, update_msg)
              end
            else
              # Fail.
              write(ws, string(imgToStr(img, x, y, 1, 1)))
            end
            last_update = new_update
          end
        catch
          # Socket went away (disconnected), most likely. Ignore it.
        end
        filter!(x -> x !== ws, connections)
      end
    else
      write(stream, "404 not found (this is a good error page, what are you talking about)")
      stream.message.response.status = 404
    end
  end
end




# TODO: Periodically synchronize the image into a PostgreSQL database.
#   TODO: Download a Postgre server.
#   ...That piece of shit is just refusing to work. Should we go DB-less??
# TODO: Use Docker for this, just to get experience.
# TODO: ...Maybe, we should be deploying to Heroku from the start, even before the DB, to have a base to extend?

end # module