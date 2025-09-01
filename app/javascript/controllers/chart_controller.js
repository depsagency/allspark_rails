import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["canvas", "data"]
  static values = { type: String }

  connect() {
    if (this.hasDataTarget && this.hasCanvasTarget) {
      this.createChart()
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  createChart() {
    try {
      const data = JSON.parse(this.dataTarget.textContent)
      const ctx = this.canvasTarget.getContext('2d')
      
      const config = {
        type: this.typeValue || 'line',
        data: data,
        options: this.getChartOptions()
      }

      this.chart = new Chart(ctx, config)
    } catch (error) {
      console.error('Error creating chart:', error)
    }
  }

  getChartOptions() {
    const baseOptions = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'top'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      scales: {
        x: {
          display: true,
          grid: {
            display: false
          }
        },
        y: {
          display: true,
          beginAtZero: true,
          grid: {
            color: 'rgba(0, 0, 0, 0.1)'
          }
        }
      }
    }

    // Customize options based on chart type
    switch (this.typeValue) {
      case 'line':
        return {
          ...baseOptions,
          elements: {
            line: {
              tension: 0.1
            },
            point: {
              radius: 4,
              hoverRadius: 6
            }
          }
        }
      
      case 'bar':
        return {
          ...baseOptions,
          plugins: {
            ...baseOptions.plugins,
            legend: {
              display: false
            }
          }
        }
      
      case 'doughnut':
      case 'pie':
        return {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true,
              position: 'right'
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  const label = context.label || ''
                  const value = context.parsed || 0
                  const total = context.dataset.data.reduce((a, b) => a + b, 0)
                  const percentage = ((value / total) * 100).toFixed(1)
                  return `${label}: ${value} (${percentage}%)`
                }
              }
            }
          }
        }
      
      default:
        return baseOptions
    }
  }

  // Method to update chart data (for real-time updates)
  updateData(newData) {
    if (this.chart) {
      this.chart.data = newData
      this.chart.update()
    }
  }
}