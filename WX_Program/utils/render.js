module.exports = {
  drawWaveform(ctx, data) {
    const width = 300
    const height = 200
    const maxValue = Math.max(...data)
    
    ctx.clearRect(0, 0, width, height)
    ctx.beginPath()
    ctx.moveTo(0, height/2)
    
    data.forEach((value, index) => {
      const x = (index / data.length) * width
      const y = height - (value / maxValue) * height
      ctx.lineTo(x, y)
    })
    
    ctx.strokeStyle = '#1aad19'
    ctx.lineWidth = 2
    ctx.stroke()
  }
}