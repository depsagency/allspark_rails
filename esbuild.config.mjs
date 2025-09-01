#!/usr/bin/env node

import * as esbuild from 'esbuild'
import rails from 'esbuild-rails'
import path from 'path'
import { exec } from 'child_process'
import { copy } from 'esbuild-plugin-copy'

const entryPoints = [
  'application.js',
  'service-worker.js',
  'workflow_builder.js'
]
const watchDirectories = [
  './app/javascript/**/*.js',
  './app/javascript/**/*.jsx',
  './app/views/**/*.html.erb',
  './app/views/**/*.turbo_stream.erb',
  './app/assets/builds/**/*.css'
]

const config = {
  absWorkingDir: path.join(process.cwd(), 'app/javascript'),
  outdir: 'builds',
  bundle: true,
  entryPoints: entryPoints,
  minify: process.env.RAILS_ENV == 'production',
  outdir: path.join(process.cwd(), 'app/assets/builds'),
  loader: {
    '.js': 'jsx',
    '.jsx': 'jsx'
  },
  plugins: [
    rails(),
    copy({
      resolveFrom: path.join(process.cwd(), 'public/assets'),
      assets: [
        {
          from: [
            './node_modules/tinymce/**/*.js',
            './node_modules/tinymce/**/*.css'
          ],
          to: ['./tinymce'],
          keepStructure: true
        },
        {
          from: [
            './node_modules/heroicons/24/**/*.svg',
          ],
          to: ['./icons/heroicons'],
          keepStructure: true
        }
      ]
    }),
    copy({
      resolveFrom: process.cwd(),
      assets: [
        {
          from: ['./node_modules/@xyflow/react/dist/style.css'],
          to: ['./app/assets/builds/reactflow.css']
        }
      ]
    })
  ],
  sourcemap: process.argv.includes('--sourcemap')
}

if (process.argv.includes('--watch')) {
  let context = await esbuild.context({ ...config, logLevel: 'info' })
  context.watch()
  console.log('👀 Watching for changes...')
} else {
  esbuild.build(config).catch(error => {
    console.error(error)
    process.exit(1)
  })
}
console.log(`🚀 Build node esbuild complete!`)
console.log('📱 Inject PWA workbox...')
exec('workbox injectManifest workbox.config.js', (error, stdout, stderr) => {
  if (error) {
    console.error(`exec error: ${error}`)
    return
  }
});
