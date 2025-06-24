const path = require('path');
const proxyTarget = 'http://127.0.0.1:8888';
const wsTarget = proxyTarget.replace('http', 'ws');

module.exports = {
  publicPath: '/',
  outputDir: 'dist',
  assetsDir: 'static',
  lintOnSave: true,
  productionSourceMap: false,
  parallel: require('os').cpus().length > 1,

  devServer: {
    disableHostCheck: false,
    open: process.platform === 'darwin',
    host: '0.0.0.0',
    port: 8257,
    https: false,
    hotOnly: false,
    open: true,
    proxy: {
      '/api': {
        target: proxyTarget,
        changeOrigin: true,
        ws: true,
        pathRewrite: {
          '^/api': ''
        }
      },
      '/ws': {
        target: wsTarget,
        changeOrigin: true,
        ws: true,
        pathRewrite: {
          '^/ws': ''
        }
      }
    }
  },

  configureWebpack: (config) => {
    // 性能配置
    config.performance = {
      hints: 'warning',
      maxEntrypointSize: 1024 * 1024 * 1.5,
      maxAssetSize: 1024 * 1024
    };
    
    // 优化代码分割
    config.optimization = {
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          vendors: {
            name: 'chunk-vendors',
            test: /[\\/]node_modules[\\/]/,
            priority: -10,
            chunks: 'initial'
          },
          common: {
            name: 'chunk-common',
            minChunks: 2,
            priority: -20,
            chunks: 'initial',
            reuseExistingChunk: true
          }
        }
      }
    };
    
    // 生产环境配置
    if (process.env.NODE_ENV === 'production') {
      try {
        const CompressionPlugin = require('compression-webpack-plugin');
        config.plugins.push(
          new CompressionPlugin({
            algorithm: 'gzip',
            test: /\.(js|css|html|svg)$/,
            threshold: 10240,
            minRatio: 0.8
          })
        );
      } catch (e) {
        console.warn('compression-webpack-plugin 未安装，跳过Gzip压缩');
      }
    }
  },

  chainWebpack: (config) => {
    config.plugins.delete('prefetch');

    config.plugin('copy').tap(() => {
      return [
        [
          // 复制 public/img 到 static/img
          {
            from: path.resolve(__dirname, 'public/img'),
            to: path.resolve(__dirname, 'dist/static/img')
          }
        ]
      ];
    });

    if (process.env.NODE_ENV === 'production') {
      config.devtool('source-map');
    }
  }
};