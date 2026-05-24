/*
 * markdown-preview.nvim - review comments overlay
 *
 * Vanilla, build-free overlay served from /_static/comments.js and injected by
 * routes.js. Lets a reviewer attach a comment to a rendered block; the comment
 * is mapped back to the original markdown line and sent to Neovim's quickfix
 * list (see autoload/mkdp/review.vim).
 *
 * Activated only when window.__MKDP_REVIEW__ is truthy (g:mkdp_enable_review).
 */
(function () {
  'use strict'

  if (!window.__MKDP_REVIEW__) {
    return
  }

  var SOURCE_LINE_ATTR = 'data-source-line'
  var commentedLines = {} // bufnr -> Set of 1-based lnum
  var hoverTarget = null
  var popover = null

  // ---- helpers ------------------------------------------------------------

  function getBufnr() {
    // React rewrites the path to "/<bufnr>" (and combine-preview updates it on
    // change_bufnr), but the first load is "/page/<bufnr>". Take the last
    // numeric path segment.
    var segs = window.location.pathname.split('/').filter(Boolean)
    for (var i = segs.length - 1; i >= 0; i--) {
      if (/^\d+$/.test(segs[i])) {
        return Number(segs[i])
      }
    }
    return -1
  }

  function lineOf(el) {
    var block = el && el.closest ? el.closest('[' + SOURCE_LINE_ATTR + ']') : null
    if (!block) {
      return null
    }
    var raw = block.getAttribute(SOURCE_LINE_ATTR)
    if (raw == null || raw === '') {
      return null
    }
    // data-source-line is 0-based (markdown-it token.map[0]); vim is 1-based.
    return { block: block, lnum: parseInt(raw, 10) + 1 }
  }

  function markedSet(bufnr) {
    if (!commentedLines[bufnr]) {
      commentedLines[bufnr] = {}
    }
    return commentedLines[bufnr]
  }

  // ---- styles -------------------------------------------------------------

  function injectStyles() {
    var css = [
      '.mkdp-comment-btn{position:absolute;z-index:9998;width:22px;height:22px;',
      'padding:0;border:none;border-radius:4px;cursor:pointer;display:none;',
      'align-items:center;justify-content:center;font-size:13px;line-height:1;',
      'background:#2188ff;color:#fff;box-shadow:0 1px 3px rgba(0,0,0,.3);}',
      '.mkdp-comment-btn:hover{background:#0366d6;}',
      '.mkdp-comment-pop{position:absolute;z-index:9999;width:280px;',
      'background:#fff;color:#24292e;border:1px solid #d1d5da;border-radius:6px;',
      'box-shadow:0 3px 12px rgba(0,0,0,.25);padding:8px;font-size:13px;',
      'font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif;}',
      '.mkdp-comment-pop textarea{width:100%;box-sizing:border-box;min-height:64px;',
      'resize:vertical;border:1px solid #d1d5da;border-radius:4px;padding:6px;',
      'font:inherit;margin-bottom:6px;}',
      '.mkdp-comment-pop .mkdp-row{display:flex;justify-content:space-between;align-items:center;}',
      '.mkdp-comment-pop .mkdp-line{color:#6a737d;font-size:11px;}',
      '.mkdp-comment-pop button{cursor:pointer;border-radius:4px;border:1px solid #d1d5da;',
      'background:#fafbfc;padding:4px 10px;font:inherit;margin-left:6px;}',
      '.mkdp-comment-pop button.mkdp-primary{background:#2188ff;border-color:#2188ff;color:#fff;}',
      '[data-theme="dark"] .mkdp-comment-pop{background:#22272e;color:#adbac7;border-color:#444c56;}',
      '[data-theme="dark"] .mkdp-comment-pop textarea{background:#1c2128;color:#adbac7;border-color:#444c56;}',
      '[data-theme="dark"] .mkdp-comment-pop button{background:#373e47;color:#adbac7;border-color:#444c56;}',
      '.mkdp-commented{box-shadow:inset 3px 0 0 #f9c513;}',
      '.mkdp-toast{position:fixed;bottom:18px;right:18px;z-index:10000;',
      'background:#24292e;color:#fff;padding:8px 14px;border-radius:6px;font-size:13px;',
      'opacity:0;transition:opacity .2s;pointer-events:none;}',
      '.mkdp-toast.mkdp-show{opacity:.95;}'
    ].join('')
    var style = document.createElement('style')
    style.textContent = css
    document.head.appendChild(style)
  }

  // ---- toast --------------------------------------------------------------

  var toastEl = null
  var toastTimer = null
  function toast(msg) {
    if (!toastEl) {
      toastEl = document.createElement('div')
      toastEl.className = 'mkdp-toast'
      document.body.appendChild(toastEl)
    }
    toastEl.textContent = msg
    toastEl.classList.add('mkdp-show')
    clearTimeout(toastTimer)
    toastTimer = setTimeout(function () {
      toastEl.classList.remove('mkdp-show')
    }, 2200)
  }

  // ---- hover button -------------------------------------------------------

  var btn = null
  function ensureButton() {
    if (btn) {
      return
    }
    btn = document.createElement('button')
    btn.className = 'mkdp-comment-btn'
    btn.type = 'button'
    btn.title = 'Add review comment'
    btn.textContent = '💬' // speech balloon
    btn.addEventListener('click', function (e) {
      e.preventDefault()
      e.stopPropagation()
      if (hoverTarget) {
        openPopover(hoverTarget)
      }
    })
    document.body.appendChild(btn)
  }

  function positionButton(block) {
    var rect = block.getBoundingClientRect()
    btn.style.top = (rect.top + window.scrollY + 2) + 'px'
    btn.style.left = (rect.left + window.scrollX - 28) + 'px'
    btn.style.display = 'flex'
  }

  function hideButton() {
    if (btn) {
      btn.style.display = 'none'
    }
  }

  // ---- popover ------------------------------------------------------------

  function closePopover() {
    if (popover) {
      popover.parentNode && popover.parentNode.removeChild(popover)
      popover = null
    }
  }

  function openPopover(info) {
    closePopover()
    popover = document.createElement('div')
    popover.className = 'mkdp-comment-pop'
    popover.innerHTML =
      '<textarea placeholder="Leave a review comment..."></textarea>' +
      '<div class="mkdp-row">' +
      '<span class="mkdp-line">line ' + info.lnum + '</span>' +
      '<span><button type="button" class="mkdp-cancel">Cancel</button>' +
      '<button type="button" class="mkdp-primary mkdp-submit">Comment</button></span>' +
      '</div>'

    var rect = info.block.getBoundingClientRect()
    popover.style.top = (rect.bottom + window.scrollY + 4) + 'px'
    popover.style.left = (rect.left + window.scrollX) + 'px'
    document.body.appendChild(popover)

    var textarea = popover.querySelector('textarea')
    textarea.focus()

    var submit = function () {
      var text = textarea.value.trim()
      if (!text) {
        textarea.focus()
        return
      }
      sendComment(info.lnum, text)
      closePopover()
    }

    popover.querySelector('.mkdp-submit').addEventListener('click', submit)
    popover.querySelector('.mkdp-cancel').addEventListener('click', closePopover)
    textarea.addEventListener('keydown', function (e) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        submit()
      } else if (e.key === 'Escape') {
        closePopover()
      }
    })
  }

  // close popover when clicking elsewhere
  document.addEventListener('mousedown', function (e) {
    if (popover && !popover.contains(e.target) && e.target !== btn) {
      closePopover()
    }
  })

  // ---- markers ------------------------------------------------------------

  function decorate() {
    var bufnr = getBufnr()
    var set = markedSet(bufnr)
    var blocks = document.querySelectorAll('.markdown-body [' + SOURCE_LINE_ATTR + ']')
    for (var i = 0; i < blocks.length; i++) {
      var raw = blocks[i].getAttribute(SOURCE_LINE_ATTR)
      var lnum = parseInt(raw, 10) + 1
      if (set[lnum]) {
        blocks[i].classList.add('mkdp-commented')
      }
    }
  }

  function rememberLine(bufnr, lnum) {
    markedSet(bufnr)[lnum] = true
    decorate()
  }

  // re-apply markers whenever React re-renders the markdown body
  function watchBody() {
    var body = document.querySelector('.markdown-body')
    if (!body) {
      return false
    }
    var observer = new MutationObserver(function () {
      decorate()
    })
    observer.observe(body, { childList: true, subtree: true })
    decorate()
    return true
  }

  // ---- socket -------------------------------------------------------------

  function sendComment(lnum, text) {
    var socket = window.socket
    if (!socket) {
      toast('Preview socket not ready')
      return
    }
    socket.emit('add_comment', { bufnr: getBufnr(), lnum: lnum, col: 1, text: text })
  }

  function bindSocket(socket) {
    socket.on('comment_ack', function (res) {
      res = res || {}
      if (res.ok) {
        rememberLine(res.bufnr != null ? res.bufnr : getBufnr(), res.lnum)
        toast('Comment added to quickfix list')
      } else if (res.reason === 'disabled') {
        toast('Review disabled (set g:mkdp_enable_review = 1)')
      } else if (res.reason === 'empty') {
        // ignore
      } else {
        toast('Failed to add comment')
      }
    })
  }

  // window.socket is created by the React app after connect; poll for it.
  var lastSocket = null
  function pollSocket() {
    if (window.socket && window.socket !== lastSocket) {
      lastSocket = window.socket
      bindSocket(window.socket)
    }
  }

  // ---- delegated hover ----------------------------------------------------

  function onMouseOver(e) {
    var info = lineOf(e.target)
    if (!info) {
      return
    }
    hoverTarget = info
    positionButton(info.block)
  }

  function onContentLeave(e) {
    // hide the button when leaving the content area, unless moving onto the button
    if (e.relatedTarget === btn) {
      return
    }
    hideButton()
  }

  // ---- init ---------------------------------------------------------------

  function init() {
    injectStyles()
    ensureButton()

    document.addEventListener('mouseover', onMouseOver, true)
    var page = document.getElementById('page-ctn') || document.body
    page.addEventListener('mouseleave', onContentLeave)

    // reposition button / popover on scroll & resize is intentionally skipped:
    // the button hides on scroll-away via the next hover; popover is short-lived.

    setInterval(pollSocket, 500)
    pollSocket()

    // body may not exist yet (first render); retry until present
    if (!watchBody()) {
      var tries = 0
      var t = setInterval(function () {
        if (watchBody() || ++tries > 40) {
          clearInterval(t)
        }
      }, 250)
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()
