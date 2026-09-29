-- Sample script for gcg
setBG("betty.mp4")
addElement("[pos:100,100,100,100]Hello Lua!")
delay(500)
addElement("[pos:400,400,-110,-31][rect: 600,600][fractal:1] Floating Fractal")
delay(500)
addElement("[pos:600,300][rect: 500,500][plasma:5] Plasma Element")
delay(10000)
setBG("kitten.png");
delElement(0) -- Remove the first element
delay(1000)
delElement(0) -- Remove the new first element
