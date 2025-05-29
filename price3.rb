# Gemfile
gem 'sqlite3'

# =====================  app.rb  =====================
require 'sqlite3'
require 'sinatra'
require 'sequel'

# -------- DATABASE --------
DB = Sequel.sqlite('cms.db')

DB.create_table?(:pages) do
  primary_key :id
  String  :title, null: false
  String  :slug,  null: false, unique: true
  Text    :body,  null: false, default: ''
  DateTime :created_at
  DateTime :updated_at
end
class Page < Sequel::Model; end

DB.create_table?(:settings) { String :key, primary_key: true; Text :value }
class Setting < Sequel::Model(:settings); unrestrict_primary_key; end

{
  'header_title_tpl' => 'האדר ברירת מחדל',
  'header_bg'        => '#003366',
  'header_height'    => '120',
  'header_font_size' => '32',
  'footer_c1'        => '<p>קונטיינר 1</p>',
  'footer_c2'        => '<p>קונטיינר 2</p>',
  'footer_c3'        => '<p>קונטיינר 3</p>'
}.each { |k,v| Setting.create(key: k, value: v) unless Setting[k] }

# -------- SINATRA --------
set :bind, '0.0.0.0'
set :port, 4567

helpers do
  # שורת ה־helper שמחסלת את ה־NameError
  def nav_admin = erb :nav_admin

  def build_header(page_title=nil)
    tpl   = Setting['header_title_tpl'].value
    title = tpl.gsub('[#כותרת עמוד]', page_title.to_s)
    bg,h,fs = %w[header_bg header_height header_font_size].map{ |k| Setting[k].value }
    <<~HTML
      <header style="background:#{bg};color:#fff;display:flex;align-items:center;justify-content:center;height:#{h}px">
        <h1 style="margin:0;font-size:#{fs}px">#{title}</h1>
      </header>
    HTML
  end

  def build_footer
    bg  = Setting['header_bg'].value
    c1,c2,c3 = %w[footer_c1 footer_c2 footer_c3].map{ |k| Setting[k].value }
    <<~HTML
      <footer style="background:#{bg};color:#fff;padding:20px 0">
        <div style="max-width:1200px;margin:0 auto;display:flex;justify-content:space-around;flex-wrap:wrap;gap:20px">
          <div>#{c1}</div><div>#{c2}</div><div>#{c3}</div>
        </div>
      </footer>
    HTML
  end
end

# --- BEFORE כלליים (footer קבוע) ---
before { @site_footer = build_footer }

# --- BEFORE רק לדף תוכן /p/:slug ---
before '/p/:slug' do
  @page = Page.first(slug: params[:slug]) or halt 404
  @site_header = build_header(@page.title) # כותרת דינמית
end

# --- BEFORE ברירת-מחדל לשאר הדפים (ללא כותרת דינמית) ---
before do
  @site_header ||= build_header           # אם לא הוגדר קודם
end

# -------- FRONT --------
get '/' do
  @base_prices = [
    {service:'פתיחת סתימה',price:500},
    {service:'איתור נזילה',price:800},
    {service:'החלפת ברז',price:350},
    {service:'התקנת מחמם מים',price:1200},
    {service:'ביקור חירום (לילה/סופ״ש)',price:650}
  ]
  erb :index
end

get '/p/:slug' do
  erb :public_page   # @page כבר קיים מה-before
end

# -------- ADMIN – ספציפי --------
get '/admin/header' do
  @h_title_tpl,@h_bg,@h_height,@h_font_size =
    %w[header_title_tpl header_bg header_height header_font_size].map{ |k| Setting[k].value }
  erb :admin_header
end
post '/admin/header' do
  %w[title_tpl bg height font_size].each do |k|
    Setting["header_#{k.sub('title_tpl','title_tpl')}"].update(value: params[k])
  end
  redirect '/admin/header?saved=1',303
end

get '/admin/footer' do
  @c1,@c2,@c3 = %w[footer_c1 footer_c2 footer_c3].map{ |k| Setting[k].value }
  erb :admin_footer
end
post '/admin/footer' do
  %w[c1 c2 c3].each{ |k| Setting["footer_#{k}"].update(value: params[k]) }
  redirect '/admin/footer?saved=1',303
end

post '/admin/:id/delete' do
  Page[params[:id]]&.delete
  redirect '/admin/pages?saved=1',303
end

# -------- ADMIN – Pages --------
get('/admin'){redirect '/admin/pages'}
get('/admin/pages') { @pages = Page.order(:id); erb :admin_pages }
get('/admin/new')   { @page  = Page.new;        erb :admin_form }

post '/admin' do
  Page.create(title:params[:title],slug:params[:slug],body:params[:body],
              created_at:Time.now,updated_at:Time.now)
  redirect '/admin/pages'
end

get '/admin/:id/edit' do
  @page = Page[params[:id]] or halt 404
  erb :admin_form
end
post '/admin/:id' do
  Page[params[:id]]&.update(title:params[:title],slug:params[:slug],
                            body:params[:body],updated_at:Time.now)
  redirect '/admin/pages'
end

# ---------------- TEMPLATES ----------------
__END__

@@ layout
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>מערכת מחירים</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
body{margin:0;font-family:Arial,Helvetica,sans-serif;direction:rtl}
.container{max-width:1200px;margin:0 auto;padding:1rem}
.nav-admin{background:#eee;padding:.5rem .75rem;margin-bottom:1rem;border-bottom:3px solid #003366}
.nav-admin a{margin-left:1rem;text-decoration:none;font-weight:bold;color:#003366}
table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:.5rem;text-align:center}
.btn{background:#FFD700;border:none;padding:.4rem .8rem;border-radius:4px;cursor:pointer}
.btn-delete{background:#d9534f;color:#fff}
.notice{color:green;font-weight:bold;margin-top:.5rem}
</style></head><body>
<%= @site_header %>
<% if params[:saved] %><p class="notice">הפעולה בוצעה בהצלחה ✔</p><% end %>
<%= yield %>
<%= @site_footer %>
</body>
</html>

@@ nav_admin
<div class="nav-admin">
  <a href="/admin/pages"><i class="fa fa-file-alt"></i> עמודים</a>
  <a href="/admin/header"><i class="fa fa-heading"></i> Header</a>
  <a href="/admin/footer"><i class="fa fa-window-maximize"></i> Footer</a>
  <a href="/" target="_blank"><i class="fa fa-home"></i> לאתר ←</a>
</div>

@@ admin_pages
<%= erb :nav_admin %>
<div class="container">
<h2>ניהול עמודים</h2>
<a class="btn" href="/admin/new">➕ עמוד חדש</a><br><br>
<table>
<thead><tr><th>ID</th><th>כותרת</th><th>Slug</th><th>פעולות</th></tr></thead>
<tbody>
<% @pages.each do |p| %>
  <tr>
    <td><%= p.id %></td>
    <td><%= p.title %></td>
    <td><a href="/p/<%= p.slug %>" target="_blank"><%= p.slug %></a></td>
    <td>
      <a href="/admin/<%= p.id %>/edit">✎ עריכה</a> |
      <form style="display:inline" method="post" action="/admin/<%= p.id %>/delete"
            onsubmit="return confirm('האם אתה בטוח שברצונך למחוק?');">
        <button class="btn btn-delete">🗑 מחיקה</button>
      </form>
    </td>
  </tr>
<% end %>
</tbody>
</table>
</div>


@@ admin_form
<%= nav_admin %>
<div class="container">
<h2><%= @page.id ? 'עריכת עמוד' : 'יצירת עמוד חדש' %></h2>
<form method="post" action="<%= @page.id ? "/admin/#{@page.id}" : '/admin' %>">
  <label>כותרת:<br><input type="text" name="title" value="<%= @page.title %>" required style="width:100%"></label><br><br>
  <label>Slug:<br><input type="text" name="slug" value="<%= @page.slug %>" required style="width:100%"></label><br><br>
  <label>HTML תוכן:<br><textarea name="body" style="width:100%;height:300px"><%= @page.body %></textarea></label><br><br>
  <button class="btn">💾 שמירה</button>
</form>
</div>


@@ admin_footer
<%= nav_admin %>
<div class="container">
<h2>עריכת Footer</h2>
<form method="post" action="/admin/footer">
  <% [[:c1,'קונטיינר 1'],[:c2,'קונטיינר 2'],[:c3,'קונטיינר 3']].each do |key,label| %>
    <label><%= label %> (HTML):<br>
      <textarea name="<%= key %>" style="width:100%;height:120px"><%= instance_variable_get("@#{key}") %></textarea></label><br><br>
  <% end %>
  <button class="btn">💾 שמירה</button>
</form>
</div>

@@ index
<!-- ①  CSS ו־Google Fonts / Chart.js רק לבית  -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
  :root{--brand-yellow:#FFD700;--brand-blue:#003366;--brand-black:#000;--brand-white:#fff}
  body{background:var(--brand-white);color:var(--brand-black)}
  header{background:var(--brand-blue);color:#fff;padding:1.5rem;text-align:center}
  h1,h2{margin:0 0 1rem}
  .container{max-width:1200px;margin:0 auto;padding:1rem}
  .section{margin-bottom:3rem}
  .brand-btn{background:var(--brand-yellow);border:none;padding:.5rem 1rem;font-weight:bold;border-radius:4px;cursor:pointer}
  #trust-icons{display:flex;gap:1rem;justify-content:space-around;flex-wrap:wrap}
  .icon-card{text-align:center;padding:1rem;max-width:200px}
  .icon-card i{font-size:2rem;color:var(--brand-yellow)}
  .price-table{width:100%;border-collapse:collapse}
  .price-table th,.price-table td{border:1px solid #000;padding:.5rem;text-align:center}
  .price-table thead{background:var(--brand-blue);color:#fff}
  .faq-item{margin-bottom:1rem;border:1px solid var(--brand-blue);border-radius:6px;overflow:hidden}
  .faq-item summary{padding:.75rem;background:var(--brand-blue);color:#fff;cursor:pointer}
  .faq-item p{padding:.75rem}
  .carousel{display:flex;overflow-x:auto;gap:1rem;padding-bottom:1rem}
  .carousel a{flex:0 0 auto;min-width:200px;background:var(--brand-yellow);color:#000;
              display:flex;align-items:center;justify-content:center;padding:1rem;border-radius:6px;
              text-decoration:none;font-weight:bold}
  #calculator-result{font-size:1.25rem;margin-top:.5rem}
</style>

<header>
  <h1>מחשבון / מחירי אינסטלטור</h1>
</header>

<div class="container">
  <!-- Trust Icons -->
  <section class="section" id="trust-icons">
    <div class="icon-card"><i class="fa-solid fa-shield"></i><p>שקיפות מלאה במחירים</p></div>
    <div class="icon-card"><i class="fa-solid fa-handshake-angle"></i><p>מחירים ממוצעים בענף</p></div>
    <div class="icon-card"><i class="fa-solid fa-user-check"></i><p>נתונים מעודכנים מדי חודש</p></div>
  </section>

  <!-- Top content -->
  <section class="section" id="top-content">
    <p>בכדי לעזור לך לחשב עלויות עבודות אינסטלציה, ריכזנו עבורך מחירון עדכני ומחשבונים אינטראקטיביים.</p>
  </section>

  <!-- Calculator -->
  <section class="section" id="calculator">
    <h2>מחשבון עלות שירות</h2>
    <label for="service-select">בחר שירות:</label>
    <select id="service-select"></select>
    <label for="quantity-input">כמות:</label>
    <input type="number" id="quantity-input" min="1" value="1">
    <button class="brand-btn" id="calc-btn">חשב</button>
    <div id="calculator-result"></div>
    <div style="margin-top:1rem;">
      <label for="adjust-slider">שינוי מחירים (%): </label>
      <input type="range" id="adjust-slider" min="-30" max="30" value="0">
      <span id="adjust-value">0%</span>
    </div>
  </section>

  <!-- Price trend chart -->
  <section class="section">
    <h2>ממוצע מחירי אינסטלטור לפי שנים</h2>
    <canvas id="priceChart" height="120"></canvas>
  </section>

  <!-- Price list table -->
  <section class="section" id="price-list">
    <h2>מחירון אינסטלטור</h2>
    <table class="price-table">
      <thead><tr><th>שירות</th><th>מחיר (₪)</th></tr></thead>
      <tbody id="price-table-body"></tbody>
    </table>
  </section>

  <!-- FAQ -->
  <section class="section" id="faq">
    <h2>שאלות נפוצות בנוגע למחירי אינסטלטור</h2>
    <div class="faq-item"><details><summary>כמה עולה פתיחת סתימה?</summary>
      <p>המחיר הממוצע לפתיחת סתימה נע בין 400 ל־650 ₪, בהתאם לחומרת הסתימה ומיקום הצנרת.</p></details></div>
    <div class="faq-item"><details><summary>האם המחירים כוללים חלקי חילוף?</summary>
      <p>ברוב המקרים המחירים אינם כוללים חלקים. במידה ונדרש חלק חילוף, עלות החלק תתווסף למחיר העבודה.</p></details></div>
  </section>

  <!-- Client carousel -->
  <section class="section"><h2>לקוחות שהשתמשו בשירות</h2>
    <div class="carousel" id="client-carousel">
      <a href="#">צינור פלוס</a><a href="#">בית ונכס</a><a href="#">פלומברו</a><a href="#">אינסטלטור-על</a>
    </div>
  </section>
</div>

<script>
const basePrices = <%= @base_prices.to_json %>;
let currentAdjustment = 0;

/* ---------- UI helpers ---------- */
function populate(){
  const s = document.getElementById('service-select');
  s.innerHTML = '';
  basePrices.forEach((it,i)=>{
    const o = document.createElement('option');
    o.value = i;
    o.textContent = it.service;
    s.appendChild(o);
  });
}
function adjusted(p){return Math.round(p * (1 + currentAdjustment/100));}
function renderTable(){
  const tb = document.getElementById('price-table-body');
  tb.innerHTML = '';
  basePrices.forEach((it,i)=>{
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${it.service}</td><td contenteditable>${adjusted(it.price)}</td>`;
    tb.appendChild(tr);
  });
}
function initCalc(){
  document.getElementById('calc-btn').addEventListener('click',()=>{
    const i = +document.getElementById('service-select').value,
          q = +document.getElementById('quantity-input').value;
    document.getElementById('calculator-result').textContent =
      `עלות משוערת: ₪${(adjusted(basePrices[i].price) * q).toLocaleString()}`;
  });
}

function initChart(){
  const ctx = document.getElementById('priceChart');
  if(!ctx) return;

  const yrs = Array.from({length:11}, (_,i)=>2015+i);

  window.baseTrend     = yrs.map((_,i)=>Math.round(400 * Math.pow(1.02, i)));
  window.adjustedTrend = [...baseTrend];

  window.priceChart = new Chart(ctx,{
    type:'line',
    data:{
      labels: yrs,
      datasets:[
        {label:'מקורי',  data: baseTrend,  borderWidth:2, tension:.3},
        {label:'מותאם', data: adjustedTrend, borderWidth:2, tension:.3, borderDash:[6,6]}
      ]
    },
    options:{
      plugins:{legend:{position:'bottom'}},
      scales:{y:{beginAtZero:true}}
    }
  });
}

document.addEventListener('DOMContentLoaded', ()=>{
  populate();
  renderTable();
  initCalc();
  initChart();

  const sl = document.getElementById('adjust-slider');
  if(sl){
    sl.addEventListener('input', e=>{
      currentAdjustment = +e.target.value;
      document.getElementById('adjust-value').textContent = currentAdjustment + '%';

      // עדכון הגרף
      adjustedTrend.forEach((_,i)=>{
        adjustedTrend[i] = Math.round(baseTrend[i] * (1 + currentAdjustment/100));
      });
      priceChart.update();

      // עדכון הטבלה
      renderTable();
    });
  }
});
</script>



@@ about
<div class="container"><h2>אודות</h2><p>טקסט דמה בעברית…</p></div>

@@ public_page
<div class="container">
<h2><%= @page.title %></h2>
<div><%= @page.body %></div>
</div>


@@ admin_form
<%= erb :nav_admin %>
<div class="container">
<h2><%= @page.id ? 'עריכת עמוד' : 'יצירת עמוד חדש' %></h2>
<form method="post" action="<%= @page.id ? "/admin/#{@page.id}" : '/admin' %>">
  <label>כותרת:<br><input type="text" name="title" value="<%= @page.title %>" required style="width:100%"></label><br><br>
  <label>Slug:<br><input type="text" name="slug" value="<%= @page.slug %>" required style="width:100%"></label><br><br>
  <label>HTML תוכן:<br><textarea name="body" style="width:100%;height:300px"><%= @page.body %></textarea></label><br><br>
  <button class="btn">💾 שמירה</button>
</form>
</div>

@@ admin_header
<%= nav_admin %>
<div class="container">
  <h2>עריכת Header</h2>
  <p>טיפ: השתמש בתו <code>[#כותרת עמוד]</code> במקום שבו תרצה שהכותרת הדינמית של העמוד תופיע.</p>
  <form method="post" action="/admin/header">
    <label>תבנית כותרת:<br>
      <input type="text" name="title_tpl" value="<%= @h_title_tpl %>" style="width:100%"></label><br><br>

    <label>צבע רקע:<br>
      <input type="color" name="bg" value="<%= @h_bg %>"></label><br><br>

    <label>גובה (px):<br>
      <input type="number" name="height" min="50" value="<%= @h_height %>"></label><br><br>

    <label>גודל גופן (px):<br>
      <input type="number" name="font_size" min="10" value="<%= @h_font_size %>"></label><br><br>

    <button class="btn">💾 שמירה</button>
  </form>
</div>

