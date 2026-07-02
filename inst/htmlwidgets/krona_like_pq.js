// krona_like_pq — D3-based interactive taxonomy explorer for phyloseq objects.
// Renders a zoomable sunburst (angle = value) or treemap (area = value) from a
// nested taxonomy hierarchy produced by the R side of ggplotpq::krona_like_pq().
HTMLWidgets.widget({
  name: "krona_like_pq",
  type: "output",
  factory: function (el, width, height) {
    var svg, tooltip, infoPanel, searchInput, root, lastX;
    var optShowCollapsedPath = false;

    // The container must be position:relative for the absolute-positioned
    // info panel and tooltip to be anchored to it, not to the viewport.
    el.style.position = "relative";

    // CGPM-recommended thousands separator: NARROW NO-BREAK SPACE (U+202F).
    function cgpmFmt(n) {
      return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
    }

    function clear() {
      while (el.firstChild) el.removeChild(el.firstChild);
      svg = null;
      tooltip = null;
      infoPanel = null;
      searchInput = null;
    }

    // ---- Utility: collapse single-child internal nodes (JS mirror of R) ----
    function collapseTree(node) {
      if (!node.children || node.children.length === 0) return node;
      node.children = node.children.map(collapseTree);
      var next = [];
      for (var i = 0; i < node.children.length; i++) {
        var c = node.children[i];
        if (c.children && c.children.length === 1 &&
            c.children[0].children && c.children[0].children.length > 0) {
          var gc = c.children[0];
          // Record the skipped taxonomic path (top-down, excluding gc's name).
          gc._collapsedPath = (c._collapsedPath ? c._collapsedPath + " / " : "") +
            c.name + (gc._collapsedPath ? " / " + gc._collapsedPath : "");
          next.push(gc);
        } else {
          next.push(c);
        }
      }
      node.children = next;
      return node;
    }

    // Deep-clone a plain object (hierarchy nodes are plain JS objects before
    // d3.hierarchy() processes them, so JSON round-trip is safe and cheap).
    function deepClone(obj) {
      return JSON.parse(JSON.stringify(obj));
    }

    // Apply a color scheme keyed by rank name to a pre-built d3 hierarchy.
    // Each raw node carries colorsByRank: {RankName: "#hexcolor"}.
    function applyColorByRank(d3root, rankName) {
      d3root.each(function (d) {
        var byRank = d.data.colorsByRank;
        if (byRank && byRank[rankName]) {
          d.data._activeColor = byRank[rankName];
        } else {
          d.data._activeColor = d.data.color || "#bbb";
        }
      });
    }

    // ---- Small DOM helpers -------------------------------------------------
    function makeTitle(title) {
      if (!title) return;
      var h = document.createElement("h3");
      h.textContent = title;
      h.style.cssText =
        "font-family:sans-serif;margin:0 0 2px 0;font-size:15px;color:#222;";
      el.appendChild(h);
    }

    function makeTooltip() {
      tooltip = document.createElement("div");
      tooltip.style.cssText =
        "position:absolute;pointer-events:none;background:rgba(20,20,30,0.92);" +
        "color:#fff;padding:5px 9px;border-radius:4px;font-size:12px;" +
        "font-family:sans-serif;box-shadow:0 1px 4px rgba(0,0,0,0.4);" +
        "opacity:0;transition:opacity 0.12s;max-width:280px;word-wrap:break-word;" +
        "z-index:20;";
      el.appendChild(tooltip);
    }

    function makeInfoPanel(x) {
      if (!x.options || !x.options.showInfoPanel) return null;
      var panel = document.createElement("div");
      panel.setAttribute("data-krona-panel", "info");
      panel.style.cssText =
        "position:absolute;top:60px;right:8px;background:rgba(255,255,255,0.97);" +
        "border:1px solid #ccc;border-radius:4px;padding:8px 10px;" +
        "font-family:sans-serif;font-size:11px;min-width:180px;max-width:240px;" +
        "z-index:10;line-height:1.7;pointer-events:none;";
      panel.innerHTML = "<i style='color:#888'>Hover a section…</i>";
      el.appendChild(panel);
      return panel;
    }

    // Small inline SVG pie showing `pct` (0..1) filled in `color`, the rest a
    // light grey ring. Used by the info panel to show a taxon's share of each
    // of its ancestors.
    function miniPieSvg(pct, size, color) {
      var r = size / 2;
      var rr = r - 1;
      var bg = "#e4e4e4";
      var open =
        "<svg width='" + size + "' height='" + size +
        "' style='flex:0 0 auto'>";
      var ring =
        "<circle cx='" + r + "' cy='" + r + "' r='" + rr +
        "' fill='" + bg + "' stroke='#bbb' stroke-width='0.5'/>";
      if (!(pct > 0)) {
        return open + ring + "</svg>";
      }
      if (pct >= 1) {
        return open +
          "<circle cx='" + r + "' cy='" + r + "' r='" + rr +
          "' fill='" + color + "' stroke='#bbb' stroke-width='0.5'/></svg>";
      }
      var a = pct * 2 * Math.PI;
      var x = r + rr * Math.sin(a);
      var y = r - rr * Math.cos(a);
      var large = pct > 0.5 ? 1 : 0;
      var slice =
        "<path d='M" + r + "," + r + " L" + r + "," + (r - rr) +
        " A" + rr + "," + rr + " 0 " + large + " 1 " + x + "," + y +
        " Z' fill='" + color + "'/>";
      return open + ring + slice + "</svg>";
    }

    function updateInfoPanel(panel, d, rootNode) {
      if (!panel) return;
      // Collect ancestors from immediate parent up to (but not including) root.
      var ancestors = [];
      var anc = d.parent;
      while (anc && anc.depth > 0) {
        ancestors.push(anc);
        anc = anc.parent;
      }
      var html = "<b style='font-size:12px'>" + d.data.name + "</b>" +
        "<div style='color:#666;margin:1px 0 5px'>" + cgpmFmt(d.value) + " sequences</div>";
      if (ancestors.length > 0 || rootNode.value > 0) {
        html += "<div style='font-size:10px;color:#888;margin-bottom:3px'>% of ancestor:</div>";
      }
      ancestors.forEach(function (a) {
        var pct = a.value > 0 ? d.value / a.value : 0;
        var rowColor = a === d.parent ? "#333" : "#666";
        html +=
          "<div style='display:flex;align-items:center;gap:5px;margin:2px 0'>" +
          miniPieSvg(pct, 20, rowColor) +
          "<span><b>" + (pct * 100).toFixed(1) + "%</b> of " +
          "<i>" + a.data.name + "</i></span></div>";
      });
      if (rootNode.value > 0) {
        var pctTotal = d.value / rootNode.value;
        html +=
          "<div style='display:flex;align-items:center;gap:5px;margin:2px 0'>" +
          miniPieSvg(pctTotal, 20, "#999") +
          "<span><b>" + (pctTotal * 100).toFixed(1) + "%</b> of total</span></div>";
      }
      panel.innerHTML = html;
    }

    function collapsedPathOf(d) {
      var cp = d.data._collapsedPath;
      if (!cp && d.data.collapsed_path) {
        cp = Array.isArray(d.data.collapsed_path)
          ? d.data.collapsed_path.join(" / ")
          : d.data.collapsed_path;
      }
      return cp || "";
    }

    function showTooltip(event, d) {
      var pctRoot = root.value ? ((d.value / root.value) * 100).toFixed(2) : "0";
      var pctParent =
        d.parent && d.parent.value
          ? ((d.value / d.parent.value) * 100).toFixed(2)
          : "100";
      var html = "<b>" + d.data.name + "</b><br>";
      var cp = collapsedPathOf(d);
      if (optShowCollapsedPath && cp) {
        html += "<span style='color:#bbb'>" + cp + " / " + d.data.name +
          "</span><br>";
      }
      html +=
        "value: " + cgpmFmt(d.value) + "<br>" +
        "% of parent: " + pctParent + "%<br>" +
        "% of total: " + pctRoot + "%";
      tooltip.innerHTML = html;
      tooltip.style.opacity = 1;
      tooltip.style.left = (event.offsetX + 14) + "px";
      tooltip.style.top  = (event.offsetY + 14) + "px";
    }

    function hideTooltip() { tooltip.style.opacity = 0; }

    // ---- Toolbar -----------------------------------------------------------
    // Returns a state object {getCollapse, getMaxDepth, getFontSize, getColorBy,
    //   getSearchQuery, onCollapse, onMaxDepth, onFontSize, onColorBy, onSearch}
    function makeToolbar(x, totalDepth, onRebuild) {
      var opts = x.options || {};
      var ranks = opts.ranks || [];
      // Initialise from persisted state so the collapse checkbox reflects
      // the current render state, not the original option value.
      var saved = x._state || {};
      var state = {
        collapse: saved.collapse !== undefined ? saved.collapse : !!opts.collapseEnabled,
        maxDepth: saved.maxDepth || totalDepth,
        fontSize: saved.fontSize || 9,
        colorBy: saved.colorBy || opts.defaultColorBy || (ranks[0] || "")
      };

      var bar = document.createElement("div");
      bar.style.cssText =
        "display:flex;flex-wrap:wrap;align-items:center;gap:6px;padding:3px 4px 3px 4px;" +
        "font-family:sans-serif;font-size:11px;color:#333;background:#f5f5f5;" +
        "border-bottom:1px solid #ddd;";
      el.appendChild(bar);

      function addLabel(txt) {
        var s = document.createElement("span");
        s.textContent = txt;
        s.style.cssText = "color:#555;white-space:nowrap;";
        bar.appendChild(s);
      }

      function addSep() {
        var s = document.createElement("span");
        s.textContent = "|";
        s.style.cssText = "color:#bbb;";
        bar.appendChild(s);
      }

      // --- Color by dropdown (only when multiple ranks and colorsByRank exist)
      if (ranks.length > 1) {
        addLabel("Color by:");
        var colorSel = document.createElement("select");
        colorSel.style.cssText =
          "font-size:11px;padding:1px 4px;border:1px solid #bbb;border-radius:3px;";
        ranks.forEach(function (r) {
          var opt = document.createElement("option");
          opt.value = r;
          opt.textContent = r;
          if (r === state.colorBy) opt.selected = true;
          colorSel.appendChild(opt);
        });
        colorSel.addEventListener("change", function () {
          state.colorBy = colorSel.value;
          onRebuild(state, false);
        });
        bar.appendChild(colorSel);
        addSep();
      }

      // --- Max depth selector
      if (totalDepth > 1) {
        addLabel("Depth:");
        var depthSel = document.createElement("select");
        depthSel.style.cssText =
          "font-size:11px;padding:1px 4px;border:1px solid #bbb;border-radius:3px;";
        for (var d = 1; d <= totalDepth; d++) {
          var opt2 = document.createElement("option");
          opt2.value = d;
          opt2.textContent = d;
          if (d === state.maxDepth) opt2.selected = true;
          depthSel.appendChild(opt2);
        }
        depthSel.addEventListener("change", function () {
          state.maxDepth = +depthSel.value;
          onRebuild(state, false);
        });
        bar.appendChild(depthSel);
        addSep();
      }

      // --- Font size
      addLabel("Font:");
      var fontSel = document.createElement("select");
      fontSel.style.cssText =
        "font-size:11px;padding:1px 4px;border:1px solid #bbb;border-radius:3px;";
      [7, 9, 10, 11, 13].forEach(function (sz) {
        var opt3 = document.createElement("option");
        opt3.value = sz;
        opt3.textContent = sz + "px";
        if (sz === state.fontSize) opt3.selected = true;
        fontSel.appendChild(opt3);
      });
      fontSel.addEventListener("change", function () {
        state.fontSize = +fontSel.value;
        onRebuild(state, false);
      });
      bar.appendChild(fontSel);
      addSep();

      // --- Collapse toggle
      var collLbl = document.createElement("label");
      collLbl.style.cssText =
        "display:flex;align-items:center;gap:3px;cursor:pointer;white-space:nowrap;";
      var collChk = document.createElement("input");
      collChk.type = "checkbox";
      collChk.checked = state.collapse;
      collChk.style.cssText = "cursor:pointer;";
      collChk.addEventListener("change", function () {
        state.collapse = collChk.checked;
        onRebuild(state, true);
      });
      collLbl.appendChild(collChk);
      collLbl.appendChild(document.createTextNode("Collapse"));
      bar.appendChild(collLbl);

      // --- Reset button
      addSep();
      var resetBtn = document.createElement("button");
      resetBtn.textContent = "Reset";
      resetBtn.title = "Reset zoom to root";
      resetBtn.style.cssText =
        "font-size:11px;padding:1px 8px;border:1px solid #bbb;border-radius:3px;" +
        "background:#fff;cursor:pointer;";
      // onclick is wired to the active reset handler by renderSunburst /
      // renderTreemap (which own the focus state).
      bar.appendChild(resetBtn);

      // --- Search box (always available, for both sunburst and treemap)
      addSep();
      addLabel("Search:");
      var inp = document.createElement("input");
      inp.type = "text";
      inp.placeholder = "Filter taxa…";
      inp.style.cssText =
        "font-size:11px;padding:2px 6px;border:1px solid #bbb;" +
        "border-radius:3px;min-width:90px;";
      bar.appendChild(inp);
      searchInput = inp;

      resetBtn._onResetRef = null;
      state._resetBtn = resetBtn;
      return state;
    }

    // ---- Sunburst ----------------------------------------------------------
    function renderSunburst(data, w, h, x, state) {
      var opts = x.options || {};
      var maxDepth = state ? state.maxDepth : 99;
      var fontSize = state ? state.fontSize : 9;
      var colorBy  = state ? state.colorBy  : (opts.defaultColorBy || "");

      // Enforce a minimum size so the chart is readable. Leaf labels sit
      // outside the rim by default (see LEAF_PAD below), so a fixed margin
      // is reserved from the circle's own radius rather than the canvas.
      var size = Math.max(200, Math.min(w, h - 44) - 10);
      var LEAF_ROOM = 60;
      var radius = Math.max(60, size / 2 - LEAF_ROOM);

      svg = d3.select(el).append("svg")
        .attr("width", w)
        .attr("height", h)
        .style("font-family", "sans-serif");

      var g = svg.append("g")
        .attr("transform", "translate(" + (radius + 4) + "," + (radius + 42) + ")");

      root = d3.hierarchy(data)
        .sum(function (d) {
          return (!d.children || d.children.length === 0) ? d.value : 0;
        })
        .sort(function (a, b) { return b.value - a.value; });

      d3.partition().size([2 * Math.PI, radius])(root);

      // Assign active colors from the chosen rank (or default).
      applyColorByRank(root, colorBy);

      var arc = d3.arc()
        .startAngle(function (d) { return d.x0; })
        .endAngle(function (d)   { return d.x1; })
        .padAngle(0.004)
        .padRadius(radius / 2)
        .innerRadius(function (d) { return Math.max(0, d.y0); })
        .outerRadius(function (d) { return Math.max(0, d.y1 - 1); });

      // A node is part of a same-named fill chain (unassigned / "n more") when
      // it has a single same-named child, or its parent shares its name. Such
      // segments render borderless (so the chain looks like one wedge) and only
      // the outermost segment is labelled.
      function isChainInner(d) {
        return d.children && d.children.length === 1 &&
          d.children[0].data.name === d.data.name;
      }
      function inFillChain(d) {
        return isChainInner(d) ||
          (d.parent && d.parent.data && d.parent.data.name === d.data.name);
      }

      var cell = g.selectAll("path")
        .data(root.descendants().filter(function (d) {
          return d.depth > 0 && d.depth <= maxDepth;
        }))
        .enter().append("path")
        .attr("d", arc)
        .attr("fill", function (d) { return d.data._activeColor || "#bbb"; })
        .attr("stroke", function (d) { return inFillChain(d) ? "none" : "#fff"; })
        .attr("stroke-width", 0.5)
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
          showTooltip(event, d);
          var panel = el.querySelector("[data-krona-panel='info']");
          updateInfoPanel(panel, d, root);
        })
        .on("mousemove", showTooltip)
        .on("mouseout", hideTooltip);


      // ---- Krona-style radial/tangential labels ------------------------------
      // Leaf labels default to RADIAL (a spoke reading straight outward,
      // anchored outside the coloured rim by LEAF_PAD), falling back to
      // TANGENTIAL (running along the arc) only when the wedge is too
      // narrow for a spoke. Internal labels default to TANGENTIAL (reading
      // around their own ring band), falling back to RADIAL only when even
      // that does not fit -- the opposite priority from leaf labels, and a
      // thin-wedge dot is the last resort for both. This matches the static
      // R path's "auto" styling (leaf = spoke, internal = arc-following).
      // Classification is recomputed on every zoom (see `classifyLabels`)
      // since a wedge's angular width relative to the full circle changes
      // once an ancestor becomes the new focus.
      var LEAF_PAD = 14;

      function isLeaf(d) {
        return !d.children || d.children.length === 0;
      }
      // On the right half (mid < PI) the anchor is the start of the text so
      // it reads outward; on the left half text is rotated 180 deg and
      // anchored at its end, so it still reads outward and is never
      // upside-down. `mid` is the wedge mid-angle in radians (clockwise from
      // north); `r` is the anchor radius.
      function radialLabelTransform(mid, r) {
        var x = mid * 180 / Math.PI;
        var extra = x > 180 ? 180 : 0;
        return "rotate(" + (x - 90) + ") translate(" + r + ",0) rotate(" + extra + ")";
      }
      function radialAnchor(mid) {
        return mid > Math.PI ? "end" : "start";
      }
      // Tangential text's own "upright" direction rotates through vertical at
      // the EAST/WEST cardinal points (mid = 90 deg/270 deg, since d3's
      // angle 0 is north) -- a different axis than the radial case above,
      // which flips at north/south instead. Flipping at the wrong axis (a
      // past bug here) leaves text near-upside-down through most of one
      // hemisphere; verified against a synthetic 8-wedge test circle.
      function tangentialLabelTransform(mid, r) {
        var x = mid * 180 / Math.PI;
        var norm = ((x % 360) + 360) % 360;
        var textRot = (norm > 90 && norm < 270) ? 270 : 90;
        return "rotate(" + (x - 90) + ") translate(" + r + ",0) rotate(" + textRot + ")";
      }
      // Middle-ellipsis shortening for pathologically long names only.
      function shortenMid(name, n) {
        if (name.length <= n) return name;
        var half = Math.max(1, Math.floor((n - 1) / 2));
        return name.slice(0, half) + "…" + name.slice(name.length - half);
      }
      // Radial fit: the wedge must be angularly wide enough (at its own
      // band mid-radius) to fit the font's physical height -- independent of
      // label length, mirroring Krona's minWidth() rule and the static path.
      function radialFits(arcw, rMid) {
        return arcw * rMid >= fontSize * 1.25;
      }
      // Tangential fit: text width (chars * ~0.62 * fontSize, the same
      // character-width heuristic already used for the treemap labels) must
      // fit the arc length at the band mid-radius.
      function tangentialFits(name, arcw, rMid) {
        return name.length * fontSize * 0.62 <= arcw * rMid;
      }

      // ---- Thin out radially-oriented labels that would visually collide ----
      // Port of the static R path's `.dismiss_overlapping_labels()`: sort
      // candidates by value descending, keep one only if it is >= minGap
      // radians from every already-kept label *in the same group* (group =
      // same physical ring, so an internal label and an unrelated leaf
      // callout -- different radii -- are never compared). Returns the
      // array of dismissed (losing) nodes.
      var dismissOverlaps = true;
      function dismissOverlappingLabels(nodes, minGap, groupFn) {
        var sorted = nodes.slice().sort(function (a, b) { return b.value - a.value; });
        var keptAngles = {};
        var dismissed = [];
        sorted.forEach(function (d) {
          var g = String(groupFn(d));
          var prev = keptAngles[g];
          var ok = !prev || prev.every(function (a) {
            return Math.abs(((a - d._mid + Math.PI) % (2 * Math.PI)) - Math.PI) >= minGap;
          });
          if (ok) {
            (keptAngles[g] = keptAngles[g] || []).push(d._mid);
          } else {
            dismissed.push(d);
          }
        });
        return dismissed;
      }

      // Inner segments of a fill chain are not labelled (only the outermost
      // is). Deliberately NOT pre-filtered by angular width here: whether a
      // wedge has room for a label depends on the CURRENT zoom (its angular
      // width relative to the current focus, rescaled in `classifyLabels`),
      // not its width in the full, un-zoomed tree. A wedge too thin to label
      // at the root view can easily fill most of the circle once zoomed into
      // its parent, and must be re-classified then -- not permanently
      // excluded because it missed a one-time filter computed before any
      // zoom happened. `radialFits`/`tangentialFits` (called from
      // `classifyLabels` with the rescaled width) are what actually decide
      // whether a wedge gets a real label, falling back to a dot otherwise.
      var allVisible = root.descendants().filter(function (d) {
        return d.depth > 0 && d.depth <= maxDepth &&
          (d.x1 - d.x0) > 0 && !isChainInner(d);
      });

      var labelSel = g.selectAll("text.krona-label")
        .data(allVisible)
        .enter().append("text")
        .attr("class", "krona-label")
        .style("pointer-events", "none")
        .attr("dominant-baseline", "middle");

      // Recompute every label's rescaled angle, orientation, and overlap
      // status against the current zoom focus `v`, then update the shared
      // selection. Called once at initial render (v = root) and again as
      // the first step of every `zoomTo(v)`.
      function classifyLabels(v) {
        var x0 = v.x0, angle = v.x1 - v.x0;
        var maxY = v.y1;
        v.each(function (d) { if (d.y1 > maxY) maxY = d.y1; });
        var yScale = maxY > v.y0 ? radius / (maxY - v.y0) : 1;
        var ry = function (y) {
          return Math.max(0, Math.min(radius, (y - v.y0) * yScale));
        };
        var inSubtree = new Set(v.descendants());
        inSubtree.delete(v);

        // The rescale formulas below are only meaningful for actual
        // descendants of the focus `v` -- for any other (hidden) node,
        // `(d.x0 - x0) / angle` divides by an angle that has nothing to do
        // with that node's position, producing near-arbitrary nx0/nx1.
        // Classifying those anyway would let their garbage `_mid` values
        // leak into the overlap-dismissal comparison below and wrongly
        // demote real, visible candidates. Give hidden nodes a trivial
        // "dot" role (irrelevant, since they're display:none) and skip them.
        var labelCands = [];
        allVisible.forEach(function (d) {
          if (!inSubtree.has(d)) {
            d._role = "dot";
            return;
          }
          var nx0 = ((d.x0 - x0) / angle) * 2 * Math.PI;
          var nx1 = ((d.x1 - x0) / angle) * 2 * Math.PI;
          d._mid = (nx0 + nx1) / 2;
          var arcw = nx1 - nx0;
          var leaf = isLeaf(d);
          var rMid = leaf ? radius : (ry(d.y0) + ry(d.y1)) / 2;
          d._leaf = leaf;
          d._r = leaf ? (radius + LEAF_PAD) : rMid;
          d._room = leaf ? 40 : Math.max(4, Math.floor(
            (ry(d.y1) - ry(d.y0)) / (fontSize * 0.62)
          ));
          if (leaf) {
            if (radialFits(arcw, rMid)) {
              d._role = "radial";
              labelCands.push(d);
            } else if (tangentialFits(d.data.name, arcw, rMid)) {
              d._role = "tangential";
              d._r = radius;
              labelCands.push(d);
            } else {
              d._role = "dot";
            }
          } else if (tangentialFits(d.data.name, arcw, rMid)) {
            d._role = "tangential";
            labelCands.push(d);
          } else if (radialFits(arcw, rMid)) {
            d._role = "radial";
            labelCands.push(d);
          } else {
            d._role = "dot";
          }
        });

        if (dismissOverlaps && labelCands.length > 0) {
          dismissOverlappingLabels(labelCands, 0.26, function (d) {
            return d._leaf ? "leaf" : d.depth;
          }).forEach(function (d) { d._role = "dot"; });
        }

        labelSel
          .style("display", function (d) { return inSubtree.has(d) ? null : "none"; })
          .style("font-size", function (d) {
            return (d._role === "dot" ? fontSize + 2 : fontSize) + "px";
          })
          .style("fill", function (d) {
            if (d._role === "dot") {
              return (d._leaf || d.data.is_aggregate) ? "#444" : "#fff";
            }
            return (d._leaf || d.data.is_aggregate) ? "#111" : "#fff";
          })
          .text(function (d) {
            if (d._role === "dot") return "·";
            return shortenMid(d.data.name, d._room);
          })
          .attr("text-anchor", function (d) {
            if (d._role === "tangential") return "middle";
            if (d._role === "dot") return "middle";
            return radialAnchor(d._mid);
          })
          .transition().duration(550)
          .attr("transform", function (d) {
            if (d._role === "tangential" || d._role === "dot") {
              return tangentialLabelTransform(d._mid, d._r);
            }
            return radialLabelTransform(d._mid, d._r);
          });
      }

      classifyLabels(root);

      // Centre count label — placed at (0, 0) which is the pole of the chart.
      var centerLabel = null;
      if (opts.showCenterCount) {
        centerLabel = g.append("text")
          .attr("x", 0)
          .attr("y", 0)
          .attr("dy", "0.35em")
          .attr("text-anchor", "middle")
          .style("font-size", "12px")
          .style("font-weight", "bold")
          .style("fill", "#333")
          .style("pointer-events", "none")
          .text("n = " + cgpmFmt(root.value));
      }

      // Breadcrumb bar.
      var crumb = document.createElement("div");
      crumb.style.cssText =
        "font-family:sans-serif;font-size:11px;margin:2px 0 1px 4px;color:#555;" +
        "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;";
      el.insertBefore(crumb, svg.node());
      function updateBreadcrumb(d) {
        var path = [];
        var node = d;
        while (node) { path.unshift(node.data.name); node = node.parent; }
        crumb.textContent = path.join(" ›");
      }
      updateBreadcrumb(root);

      // Zoom on click. Radii are rescaled so the focused subtree fills the
      // full radius — the overall circle keeps the same global size on every
      // zoom level instead of shrinking inward.
      function zoomTo(v) {
        var angle = v.x1 - v.x0;
        var x0 = v.x0, y0 = v.y0;
        // Outermost radius reached by any descendant of the focus, so we can
        // scale [y0, maxY] back onto [0, radius].
        var maxY = v.y1;
        v.each(function (d) { if (d.y1 > maxY) maxY = d.y1; });
        var yScale = maxY > y0 ? radius / (maxY - y0) : 1;
        var ry = function (y) {
          return Math.max(0, Math.min(radius, (y - y0) * yScale));
        };
        // The rescale formulas above are only valid for nodes strictly inside
        // the focused subtree: an ancestor or an unrelated sibling has
        // y0 <= v.y0, so `ry` clamps it to 0 -- collapsing its wedge (and
        // label) onto the centre point instead of leaving the view. Hide
        // everything outside `v`'s own descendants (v itself included, so
        // the focus becomes the blank hub around the centre count).
        var inSubtree = new Set(v.descendants());
        inSubtree.delete(v);
        function focused(d) { return inSubtree.has(d); }

        g.selectAll("path")
          .style("display", function (d) { return focused(d) ? null : "none"; })
          .style("pointer-events", function (d) { return focused(d) ? null : "none"; })
          .transition().duration(550)
          .attrTween("d", function (d) {
            var i = d3.interpolate(
              { x0: d.x0, x1: d.x1, y0: d.y0, y1: d.y1 },
              {
                x0: ((d.x0 - x0) / angle) * 2 * Math.PI,
                x1: ((d.x1 - x0) / angle) * 2 * Math.PI,
                y0: ry(d.y0),
                y1: ry(d.y1)
              }
            );
            return function (t) { return arc(i(t)); };
          });
        classifyLabels(v);
        if (centerLabel) {
          centerLabel.text("n = " + cgpmFmt(v.value));
        }
      }

      var focus = root;
      function doReset() {
        focus = root;
        zoomTo(root);
        updateBreadcrumb(root);
      }
      if (state._resetBtn) {
        state._resetBtn._onResetRef = doReset;
        state._resetBtn.onclick = doReset;
      }
      cell.on("click", function (event, d) {
        event.stopPropagation();
        focus = d;
        zoomTo(d);
        updateBreadcrumb(d);
      });
      svg.on("click", function () {
        doReset();
      });

      // Search: dim non-matching paths.
      if (searchInput) {
        searchInput.addEventListener("input", function () {
          var q = searchInput.value.trim().toLowerCase();
          if (!q) { cell.style("opacity", 1); return; }
          cell.style("opacity", function (d) {
            return d.data.name.toLowerCase().indexOf(q) >= 0 ? 1 : 0.15;
          });
        });
      }
    }

    // ---- Treemap -----------------------------------------------------------
    function renderTreemap(data, w, h, x, state) {
      var opts = x.options || {};
      var maxDepth = state ? state.maxDepth : 99;
      var fontSize = state ? state.fontSize : 9;
      var colorBy  = state ? state.colorBy  : (opts.defaultColorBy || "");

      var innerW = Math.max(120, w - 8);
      var innerH = Math.max(120, h - 44);

      svg = d3.select(el).append("svg")
        .attr("width", w)
        .attr("height", h)
        .style("font-family", "sans-serif");

      var g = svg.append("g").attr("transform", "translate(2,40)");

      root = d3.hierarchy(data)
        .sum(function (d) {
          return (!d.children || d.children.length === 0) ? d.value : 0;
        })
        .sort(function (a, b) { return b.value - a.value; });

      // Header height is depth-dependent so outer ranks get more visible space.
      var HEADER = function (d) { return d.depth === 0 ? 0 : Math.max(14, 22 - d.depth * 2); };

      d3.treemap()
        .tile(d3.treemapSquarify)
        .size([innerW, innerH])
        .paddingInner(1)
        .paddingTop(HEADER)
        .paddingLeft(2).paddingRight(2).paddingBottom(2)
        .round(true)(root);

      applyColorByRank(root, colorBy);

      var allNodes = root.descendants().filter(function (d) {
        return d.depth > 0 && d.depth <= maxDepth;
      });
      var innerNodes = allNodes.filter(function (d) {
        return d.children && d.children.length > 0;
      });
      var leafNodes = allNodes.filter(function (d) {
        return !d.children || d.children.length === 0;
      });

      // Helper: truncate label to fit cell width.
      function tmLabel(name, cw, fs) {
        if (cw < 20) return "";
        var maxCh = Math.floor((cw - 6) / (fs * 0.62));
        if (maxCh < 2) return "";
        return name.length <= maxCh ? name
          : name.slice(0, Math.max(1, maxCh - 1)) + "…";
      }

      var node = g.selectAll("g.cell")
        .data(allNodes)
        .enter().append("g")
        .attr("class", "cell")
        .attr("transform", function (d) {
          return "translate(" + d.x0 + "," + d.y0 + ")";
        })
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
          showTooltip(event, d);
          var panel = el.querySelector("[data-krona-panel='info']");
          updateInfoPanel(panel, d, root);
        })
        .on("mousemove", showTooltip)
        .on("mouseout", hideTooltip);

      // Background rect for all nodes (inner nodes show only their header strip
      // since child rects are rendered on top).
      node.append("rect")
        .attr("class", "cell-bg")
        .attr("width",  function (d) { return Math.max(0, d.x1 - d.x0); })
        .attr("height", function (d) { return Math.max(0, d.y1 - d.y0); })
        .attr("fill",   function (d) { return d.data._activeColor || "#bbb"; })
        .attr("stroke", "#fff")
        .attr("stroke-width", 0.5);

      // Inner-node labels: placed in the header strip at the top of the cell.
      // Font size scales with depth so Kingdom labels are largest.
      node.filter(function (d) { return d.children && d.children.length > 0; })
        .append("text")
        .attr("class", "cell-inner-label")
        .attr("x", 3)
        .attr("y", function (d) { return HEADER(d) - 3; })
        .style("font-size", function (d) {
          return Math.max(9, Math.min(13, 16 - d.depth * 2)) + "px";
        })
        .style("font-weight", "bold")
        .style("fill", "#fff")
        .style("pointer-events", "none")
        .text(function (d) {
          var fs = Math.max(9, Math.min(13, 16 - d.depth * 2));
          return tmLabel(d.data.name, d.x1 - d.x0, fs);
        });

      // Leaf-node labels: placed inside the cell.
      node.filter(function (d) { return !d.children || d.children.length === 0; })
        .append("text")
        .attr("class", "cell-leaf-label")
        .attr("x", 4).attr("y", fontSize + 2)
        .style("font-size", fontSize + "px")
        .style("font-weight", "600")
        .style("fill", "#111")
        .style("pointer-events", "none")
        .text(function (d) {
          var cw = d.x1 - d.x0, ch = d.y1 - d.y0;
          if (cw < 24 || ch < fontSize + 4) return "";
          return tmLabel(d.data.name, cw, fontSize);
        });

      // Breadcrumb
      var crumb = document.createElement("div");
      crumb.style.cssText =
        "font-family:sans-serif;font-size:11px;margin:2px 0 1px 4px;color:#555;";
      el.insertBefore(crumb, svg.node());
      function updateBreadcrumb(d) {
        var path = [];
        var nd = d;
        while (nd) { path.unshift(nd.data.name); nd = nd.parent; }
        crumb.textContent = path.join(" ›") + "  — click cell to zoom";
      }
      updateBreadcrumb(root);

      var focus = root;
      function doResetTreemap() {
        focus = root;
        zoomTreemap(root);
        updateBreadcrumb(root);
      }
      if (state && state._resetBtn) {
        state._resetBtn.onclick = doResetTreemap;
      }
      node.on("click", function (event, d) {
        event.stopPropagation();
        focus = d;
        zoomTreemap(d);
        updateBreadcrumb(d);
      });
      svg.on("click", function () {
        focus = focus.parent || root;
        zoomTreemap(focus);
        updateBreadcrumb(focus);
      });

      function zoomTreemap(v) {
        var dx = v.x0, dy = v.y0, dw = v.x1 - v.x0, dh = v.y1 - v.y0;
        if (dw <= 0 || dh <= 0) return;
        var kx = innerW / dw, ky = innerH / dh;
        // Same rescale-the-whole-tree issue as the sunburst: a cell outside
        // v's own subtree is not meant to be positioned by this formula and
        // can land anywhere (including overlapping the zoomed content), so
        // hide anything that is not v itself or one of its descendants.
        var inSubtree = new Set(v.descendants());
        function focused(d) { return inSubtree.has(d); }

        g.selectAll("g.cell")
          .style("display", function (d) { return focused(d) ? null : "none"; })
          .style("pointer-events", function (d) { return focused(d) ? null : "none"; })
          .transition().duration(450)
          .attr("transform", function (d) {
            return "translate(" + (d.x0 - dx) * kx + "," + (d.y0 - dy) * ky + ")";
          });
        g.selectAll("g.cell rect.cell-bg").transition().duration(450)
          .attr("width",  function (d) { return Math.max(0, (d.x1 - d.x0) * kx); })
          .attr("height", function (d) { return Math.max(0, (d.y1 - d.y0) * ky); });
        g.selectAll("g.cell text.cell-inner-label").transition().duration(450)
          .attr("y", function (d) { return HEADER(d) - 3; })
          .text(function (d) {
            var fs = Math.max(9, Math.min(13, 16 - d.depth * 2));
            return tmLabel(d.data.name, (d.x1 - d.x0) * kx, fs);
          });
        g.selectAll("g.cell text.cell-leaf-label").transition().duration(450)
          .attr("y", fontSize + 2)
          .text(function (d) {
            var cw = (d.x1 - d.x0) * kx, ch = (d.y1 - d.y0) * ky;
            if (cw < 24 || ch < fontSize + 4) return "";
            return tmLabel(d.data.name, cw, fontSize);
          });
      }

      if (searchInput) {
        searchInput.addEventListener("input", function () {
          var q = searchInput.value.trim().toLowerCase();
          if (!q) { node.style("opacity", 1); return; }
          node.style("opacity", function (d) {
            return d.data.name.toLowerCase().indexOf(q) >= 0 ? 1 : 0.15;
          });
        });
      }
    }

    // ---- Main render -------------------------------------------------------
    function doRender(x, w, h, rebuildHierarchy) {
      clear();
      optShowCollapsedPath = !!(x.options && x.options.showCollapsedPath);
      makeTitle(x.title);
      makeTooltip();
      infoPanel = makeInfoPanel(x);

      if (!x.data || !x.data.name) {
        el.appendChild(document.createTextNode("No data to display."));
        return;
      }

      // Determine total depth of the original data.
      function maxDepthOf(node, d) {
        d = d || 0;
        if (!node.children || node.children.length === 0) return d;
        return Math.max.apply(null, node.children.map(function (c) {
          return maxDepthOf(c, d + 1);
        }));
      }
      var totalDepth = maxDepthOf(x.data);

      // Build the toolbar; it returns the live state object (carrying the
      // Reset button reference) and triggers a re-render on control changes.
      // Use THIS object for rendering so renderSunburst sees `_resetBtn`.
      var state = makeToolbar(x, totalDepth, function (newState, needsRebuild) {
        x._state = newState;
        doRender(x, w, h, needsRebuild);
      });
      x._state = state;

      // Prepare data: optionally collapse single-child nodes.
      var data = state.collapse ? collapseTree(deepClone(x.data)) : x.data;

      if (x.layout === "treemap") {
        renderTreemap(data, w, h, x, state);
      } else {
        renderSunburst(data, w, h, x, state);
      }
    }

    return {
      renderValue: function (x) {
        lastX = x;
        var w = width  || el.clientWidth  || 700;
        var h = height || el.clientHeight || 700;
        doRender(x, w, h, true);
      },
      resize: function (w, h) {
        if (!lastX) return;
        doRender(lastX, w || el.clientWidth || 700, h || el.clientHeight || 700, true);
      }
    };
  }
});
