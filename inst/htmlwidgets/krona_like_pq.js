// krona_like_pq — D3-based interactive taxonomy explorer for phyloseq objects.
// Renders a zoomable sunburst (angle = value) or treemap (area = value) from a
// nested taxonomy hierarchy produced by the R side of ggplotpq::krona_like_pq().
//
// Colors are assigned in R (Krona-style: child inherits parent hue with a
// lightness shift) so the static ggplot path and this interactive path share
// the same color logic. Each node carries its own `color` field in x.data.
HTMLWidgets.widget({
  name: "krona_like_pq",
  type: "output",
  factory: function (el, width, height) {
    var svg, tooltip, root, currentFocus, lastX;

    function clear() {
      while (el.firstChild) el.removeChild(el.firstChild);
    }

    function makeTitle(title) {
      if (!title) return;
      var h = document.createElement("h3");
      h.textContent = title;
      h.style.cssText =
        "font-family:sans-serif;margin:0 0 6px 0;font-size:15px;color:#222;";
      el.appendChild(h);
    }

    function makeTooltip() {
      tooltip = document.createElement("div");
      tooltip.style.cssText =
        "position:absolute;pointer-events:none;background:rgba(20,20,30,0.92);" +
        "color:#fff;padding:5px 9px;border-radius:4px;font-size:12px;" +
        "font-family:sans-serif;box-shadow:0 1px 4px rgba(0,0,0,0.4);" +
        "opacity:0;transition:opacity 0.12s;max-width:280px;word-wrap:break-word;" +
        "z-index:10;";
      el.appendChild(tooltip);
    }

    function showTooltip(event, d) {
      var pctRoot = root.value ? ((d.value / root.value) * 100).toFixed(2) : "0";
      var pctParent =
        d.parent && d.parent.value
          ? ((d.value / d.parent.value) * 100).toFixed(2)
          : "100";
      tooltip.innerHTML =
        "<b>" + d.data.name + "</b><br>" +
        "value: " + d3.format(",")(d.value) + "<br>" +
        "% of parent: " + pctParent + "%<br>" +
        "% of total: " + pctRoot + "%";
      tooltip.style.opacity = 1;
      tooltip.style.left = event.offsetX + 10 + "px";
      tooltip.style.top = event.offsetY + 10 + "px";
    }

    function hideTooltip() {
      tooltip.style.opacity = 0;
    }

    // ---- Sunburst (Krona pie: angle = value) ------------------------------
    function renderSunburst(data, w, h) {
      var size = Math.max(120, Math.min(w, h) - 10);
      var radius = size / 2;
      var elTop = el.clientHeight - size > 4 ? 24 : 6;
      var center = radius + 4;

      svg = d3
        .select(el)
        .append("svg")
        .attr("width", w)
        .attr("height", h)
        .style("font-family", "sans-serif");

      var g = svg
        .append("g")
        .attr("transform", "translate(" + center + "," + (center + elTop) + ")");

      root = d3
        .hierarchy(data)
        .sum(function (d) {
          return d.value;
        })
        .sort(function (a, b) {
          return b.value - a.value;
        });

      d3.partition().size([2 * Math.PI, radius])(root);

      var arc = d3
        .arc()
        .startAngle(function (d) {
          return d.x0;
        })
        .endAngle(function (d) {
          return d.x1;
        })
        .padAngle(0.004)
        .padRadius(radius / 2)
        .innerRadius(function (d) {
          return Math.max(0, d.y0);
        })
        .outerRadius(function (d) {
          return Math.max(0, d.y1 - 1);
        });

      var cell = g
        .selectAll("path")
        .data(root.descendants())
        .enter()
        .append("path")
        .attr("d", arc)
        .attr("fill", function (d) {
          return d.data.color || "#bbb";
        })
        .attr("stroke", "#fff")
        .attr("stroke-width", 0.5)
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
          showTooltip(event, d);
        })
        .on("mousemove", function (event, d) {
          showTooltip(event, d);
        })
        .on("mouseout", hideTooltip);

      // Krona-style click-to-zoom: the clicked node becomes the new center.
      var focus = root;
      currentFocus = focus;

      function zoomTo(v) {
        var angle = v.x1 - v.x0;
        var x0 = v.x0;
        var y0 = v.y0;
        g.selectAll("path")
          .transition()
          .duration(550)
          .attrTween("d", function (d) {
            var i = d3.interpolate(
              { x0: d.x0, x1: d.x1, y0: d.y0, y1: d.y1 },
              {
                x0: (d.x0 - x0) / angle * 2 * Math.PI,
                x1: (d.x1 - x0) / angle * 2 * Math.PI,
                y0: d.y0 - y0,
                y1: d.y1 - y0
              }
            );
            return function (t) {
              var tmp = {
                x0: i(t).x0,
                x1: i(t).x1,
                y0: i(t).y0,
                y1: i(t).y1
              };
              return arc(tmp);
            };
          });
      }

      cell.on("click", function (event, d) {
        event.stopPropagation();
        focus = d;
        currentFocus = d;
        zoomTo(d);
        updateBreadcrumb(d);
      });

      // Click the center / background to zoom out to root.
      svg.on("click", function () {
        focus = root;
        currentFocus = root;
        zoomTo(root);
        updateBreadcrumb(root);
      });

      // Breadcrumb for navigation context.
      var crumb = document.createElement("div");
      crumb.style.cssText =
        "font-family:sans-serif;font-size:12px;margin:4px 0 2px 0;color:#555;";
      el.insertBefore(crumb, el.firstChild.nextSibling || el.firstChild);
      function updateBreadcrumb(d) {
        var path = [];
        var node = d;
        while (node) {
          path.unshift(node.data.name);
          node = node.parent;
        }
        crumb.textContent = path.join(" › ") + "   (click center to reset)";
      }
      updateBreadcrumb(root);
    }

    // ---- Treemap (area = value) -------------------------------------------
    function renderTreemap(data, w, h) {
      var innerW = Math.max(120, w - 8);
      var innerH = Math.max(120, h - 30);

      svg = d3
        .select(el)
        .append("svg")
        .attr("width", w)
        .attr("height", h)
        .style("font-family", "sans-serif");

      var g = svg.append("g").attr("transform", "translate(2,24)");

      root = d3
        .hierarchy(data)
        .sum(function (d) {
          return d.value;
        })
        .sort(function (a, b) {
          return b.value - a.value;
        });

      var treemap = d3
        .treemap()
        .tile(d3.treemapSquarify)
        .size([innerW, innerH])
        .paddingInner(1)
        .paddingOuter(function (d) {
          return d.depth === 0 ? 0 : 2;
        })
        .round(true);

      treemap(root);

      var node = g
        .selectAll("g.cell")
        .data(root.descendants())
        .enter()
        .append("g")
        .attr("class", "cell")
        .attr("transform", function (d) {
          return "translate(" + d.x0 + "," + d.y0 + ")";
        })
        .style("cursor", "pointer")
        .on("mouseover", function (event, d) {
          showTooltip(event, d);
        })
        .on("mousemove", function (event, d) {
          showTooltip(event, d);
        })
        .on("mouseout", hideTooltip);

      node
        .append("rect")
        .attr("width", function (d) {
          return Math.max(0, d.x1 - d.x0);
        })
        .attr("height", function (d) {
          return Math.max(0, d.y1 - d.y0);
        })
        .attr("fill", function (d) {
          return d.data.color || "#bbb";
        })
        .attr("stroke", "#fff")
        .attr("stroke-width", 0.5);

      node
        .append("text")
        .attr("x", 4)
        .attr("y", 12)
        .style("font-size", "11px")
        .style("fill", "#fff")
        .style("pointer-events", "none")
        .style("text-shadow", "0 1px 2px rgba(0,0,0,0.6)")
        .text(function (d) {
          var cw = d.x1 - d.x0;
          var ch = d.y1 - d.y0;
          if (cw < 34 || ch < 16) return "";
          var label = d.data.name;
          return label.length * 6 < cw - 6 ? label : "";
        });

      var crumb = document.createElement("div");
      crumb.style.cssText =
        "font-family:sans-serif;font-size:12px;margin:2px 0 2px 4px;color:#555;";
      el.insertBefore(crumb, el.firstChild.nextSibling || el.firstChild);
      function updateBreadcrumb(d) {
        var path = [];
        var node = d;
        while (node) {
          path.unshift(node.data.name);
          node = node.parent;
        }
        crumb.textContent = path.join(" › ") + "   (click a cell to zoom in)";
      }
      updateBreadcrumb(root);

      // Zoom in on click; zoom out to parent on background click.
      var focus = root;
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
        var dx = v.x0,
          dy = v.y0,
          dw = v.x1 - v.x0,
          dh = v.y1 - v.y0;
        if (dw <= 0 || dh <= 0) return;
        var kx = innerW / dw,
          ky = innerH / dh;
        g.selectAll("g.cell")
          .transition()
          .duration(450)
          .attr("transform", function (d) {
            return (
              "translate(" + (d.x0 - dx) * kx + "," + (d.y0 - dy) * ky + ")"
            );
          });
        g.selectAll("g.cell rect")
          .transition()
          .duration(450)
          .attr("width", function (d) {
            return Math.max(0, (d.x1 - d.x0) * kx);
          })
          .attr("height", function (d) {
            return Math.max(0, (d.y1 - d.y0) * ky);
          });
        g.selectAll("g.cell text")
          .transition()
          .duration(450)
          .attr("x", 4)
          .attr("y", 12)
          .text(function (d) {
            var cw = (d.x1 - d.x0) * kx;
            var ch = (d.y1 - d.y0) * ky;
            if (cw < 34 || ch < 16) return "";
            var label = d.data.name;
            return label.length * 6 < cw - 6 ? label : "";
          });
      }
    }

    return {
      renderValue: function (x) {
        lastX = x;
        clear();
        makeTitle(x.title);
        makeTooltip();
        if (!x.data || !x.data.name) {
          el.appendChild(document.createTextNode("No data to display."));
          return;
        }
        var w = width ? width : el.clientWidth || 600;
        var h = height ? height : el.clientHeight || 400;
        if (x.layout === "treemap") {
          renderTreemap(x.data, w, h);
        } else {
          renderSunburst(x.data, w, h);
        }
      },
      resize: function (width, height) {
        if (!lastX) return;
        clear();
        var x = lastX;
        makeTitle(x.title);
        makeTooltip();
        var w = width ? width : el.clientWidth || 600;
        var h = height ? height : el.clientHeight || 400;
        if (x.layout === "treemap") {
          renderTreemap(x.data, w, h);
        } else {
          renderSunburst(x.data, w, h);
        }
      }
    };
  }
});
