require "hpricot"
require "open-uri"

class PCGS
	class Wallet
		attr_accessor :coins

		attr_accessor :tables

		def initialize(type=nil)
			doc = PCGS.scrape("http://www.pcgs.com/prices/")
			cols = doc.search("//div[@class='twocolumn']").first.search("//div[@class='col']")
			boxes = cols.map{|col|col.search("//div").find_all{|div|div["class"].include?("box")}}.flatten
			as = boxes.map{|box|box.search("//ul").first.search("//a")}.flatten
			urls = as.map{|a|"http://www.pcgs.com"+a["href"]}
			if not type.nil?
				urls = as.find_all{|a|a.inner_html==type}.map{|a|"http://www.pcgs.com"+a["href"]}
			end

			@tables = []

			urls.each do |url|
				# p "Getting prices for #{url.split('title=')[1].gsub('+',' ')}..."
				doc = PCGS.scrape(url)
				ti = PCGS.table_info(doc)
				ti.each do |t|
					# p "    Making table for #{t[:tab_title]}, #{t[:coin_grade_type]}."
					@tables << PCGS.objectify_table_info(t)
				end
			end

			@coins = []

			self.coinify_tables

			self
		end

		def coinify_tables
			self.tables.each do |table|
				self.coinify_table(table)
			end
		end

		def coinify_table(table)
			# p "Adding #{table.coin_type} coins to wallet..."
			table.rows.each do |row|
				if row.elements.first.is_a?(Integer)
					if row.elements[1] != "Type"
						pcgs_no = row.elements[0].to_i
						description = row.elements[1]
						design = row.elements[2]
						grade_type = table.coin_grade_type
						subtype = row.coin_subtype
						type = table.coin_type
						y = description.to_s.scan(/\d\d\d\d/)
						if y.empty?
							year = ""
						elsif y.size == 1
							year = y[0]
						elsif y.size == 2
							if description.gsub(" ","").include?(y[0]+"-"+y[1])
								year = y[0]+"-"+y[1]
							else
								year = y[0]
							end
						end
						mint_mark = description.to_s.scan(/\d\d\d\d\-[A-Z]/)[0][-1] rescue ""
						row.elements[3..-1].each do |e|
							i = row.elements.index(e)
							grade = row.header_row.elements[i]
							price = row.elements[i]
							coin = self.add_coin(pcgs_no, description, design, grade, price, grade_type, subtype, type, year, mint_mark)
							coin = coin.set_name
							# p "Adding a #{coin.name} to the wallet."
						end
					end
				end
			end
		end

		def add_coin(pcgs_no, description, design, grade, price, grade_type, subtype, type, year, mint_mark)
			coin = PCGS::Coin.new(pcgs_no, description, design, grade, price, grade_type, subtype, type, year, mint_mark)
			self.coins << coin
			coin
		end

		def coins_like(str)
			wallet = self
			types = wallet.coins.find_all{|c|c.type_like?(str)}
			names = wallet.coins.find_all{|c|c.name_like?(str)}
			(types+names).flatten.uniq
		end
	end

	class Table
		attr_accessor :coin_type
		attr_accessor :tab
		attr_accessor :coin_grade_type
		attr_accessor :rows
		attr_accessor :doc

		def initialize(coin_type, tab, coin_grade_type, doc)
			@coin_type = coin_type
			@tab = tab
			@coin_grade_type = coin_grade_type
			@rows = []
			@doc = doc
		end

		def add_row(coin_subtype, elements, header_row)
			row = PCGS::Row.new(coin_subtype, elements, header_row)
			self.rows << row
			row
		end

		def add_rows(rows)
			if not rows.empty?
				table = self
				length = rows.first.size
				subtype = table.coin_type
				header_row = nil
				hh = "<img src=\"images/expand.gif\" align=\"left\" class=\"expandcollapseimages\" border=\"0\" />"
				rows.each do |row|
					if row.size == length
						if row.first.to_s.include?(hh)
							row[0] = row[0].gsub(hh,"").to_i
						end
						if row.first.is_a?(Integer)
							table.add_row(subtype, row, header_row)
						elsif row.first[0..3] == "PCGS"
							header_row = table.add_row("Header", row, nil)
						end
					elsif row.size == 1
						if row.first.include?("Price Changes") && rows[1].first.include?("Collectors Corner")
							subtype = row.first.split(",")[0]
						end
					end
				end
			end
		end
	end

	class Row
		attr_accessor :coin_subtype
		attr_accessor :elements
		attr_accessor :header_row

		def initialize(coin_subtype, elements, header_row)
			@coin_subtype = coin_subtype
			@elements = elements
			@header_row = header_row
		end
	end

	class Coin
		attr_accessor :pcgs_no
		attr_accessor :description
		attr_accessor :design
		attr_accessor :grade
		attr_accessor :price
		attr_accessor :grade_type
		attr_accessor :subtype
		attr_accessor :type

		attr_accessor :year
		attr_accessor :mint_mark
		attr_accessor :name

		NAMES = {"halfcent" => ["halfcent", "half cent", "hapenny", "halfpenny", "half penny", "1/2cent", "1/2 cent", "1/2penny", "1/2 penny"], "cent" => ["cent", "penny", "1cent", "1 cent", "1penny", "1 penny", "onepenny", "one penny", "draped bust cent", "lincoln"], "twocent" => ["two cent", "two cents", "twocent", "twocents", "2cent", "2cents", "2 cent", "2 cents", "2penny", "2pennies", "2 penny", "2 pennies"], "threecent" => ["threecent", "threecents", "three", "three cent", "three cents", "3cent", "3cents", "3 cent", "3 cents"], "nickel" => ["nickel", "fivecent", "fivecents", "five cents", "5cent", "5cents"], "dime" => ["dime", "tencent", "tencents", "ten cents", "10cent", "10cents"], "quarter" => ["quarter", "twentyfivecent", "twentyfivecents", "twentyfive cents", "25cent", "25cents"], "halfdollar" => ["halfdollar", "half dollar"], "dollar" => ["dollar", "onedollar", "1dollar", "one dollar", "1 dollar"], "commemorative" => ["commemorative"], "silver" => ["silver", "silver coins", "silver eagles"], "gold" => ["gold", "gold coins"], "gold dollar" => ["gold dollar", "golddollar"], "silver dollar" => ["silver dollar", "silverdollar"], "silver commemorative" => ["silver commemorative", "silvercommemorative"], "gold commemorative" => ["gold commemorative", "goldcommemorative"], "templeton reid" => ["templeton", "templetonreid", "templeton reid"]}

		def initialize(pcgs_no, description, design, grade, price, grade_type, subtype, type, year, mint_mark)
			@pcgs_no = pcgs_no
			@description = description
			@design = design
			@grade = grade
			@price = price
			@grade_type = grade_type
			@subtype = subtype
			@type = type
			@year = year
			@mint_mark = mint_mark
		end

		def type_like?(type)
			type.include?(type)
		end

		def name_like?(name)
			name.include?(name)
		end

		def set_name
			coin = self
			possible_names = []
			PCGS::Coin::NAMES.values.each_index do |i|
				v = PCGS::Coin::NAMES.values[i]
				score = 0
				v.each do |name|
					n = coin.subtype.downcase.split(" ") & name.split(" ")
					score += n.size
				end
				if score > 0
					possible_names << [PCGS::Coin::NAMES.keys[i], score]
				end
			end
			coin.name = possible_names.sort_by{|e|e[1]}.reverse.first.first
			coin
		end
	end

	def self.scrape(url)
		open(URI(url)){|f|Hpricot(f)}
	end

	def self.table_from_url(url, n)
		doc = PCGS.scrape(url)
		table_from_doc(doc, n)
	end

	def self.table_from_doc(doc, n)
		doc.search("//div[@id='blue-table']").search("//table")[n]
	end

	def self.table_info(doc)
		coin_type = doc.to_s.scan(/<a href=\"\/prices\">Home<\/a>[^<]+</).first.gsub("<a href=\"/prices\">Home</a>&nbsp;&gt;&nbsp;","").split("\r")[0]
		tabs = doc.search("//div[@id='blue-table']").search("//ul")
		tab_titles = tabs.map{|t|get_tabs(t)}
		tab_links = tabs.map{|tab|tab.search("//a").map{|a|a["href"]}}
		t = []
		(0..(tab_links.size-1)).each do |i|
			tab_links[i].each_index do |j|
				tab_title = tab_titles[i][j]
				link = tab_links[i][j]
				table = table_from_url(link, i)
				coin_grade_type = ["MS","PR"][i]#doc.to_s.scan(/Copper Type Coins, \S\S/).map{|t|t.gsub("Copper Type Coins, ","")}[i]
				t << {:coin_type => coin_type, :coin_grade_type => coin_grade_type, :tab_title => tab_title, :link => link, :table => table}
			end
		end
		t
	end

	def self.get_trs(table)
		table.search("//tr")
	end

	def self.get_tds(tr)
		tr.search("//td")
	end

	def self.get_ths(tr)
		tr.search("//th")
	end

	def self.strip_span(text)
		if text.include?("<span")
			text.scan(/<span[^>]*>/).each do |replace|
				text = text.gsub(replace, " ") rescue text
			end
			text = text.gsub("</span>", "")
		else
			text
		end
	end

	def self.strip_a(text)
		if text.include?("<a")
			text.scan(/<a[^>]*>/).each do |replace|
				text = text.gsub(replace, " ") rescue text
			end
			text = text.gsub("</a>", "")
		else
			text
		end
	end

	def self.strip_br(text)
		text.gsub("<br />", "")
	end

	def self.strip_nbsp(text)
		text.gsub("&nbsp;", " ")
	end

	def self.pick_element(text)
		if text[-1] == "-"
			text = text[0..-2]
		elsif text[-2..-1] == " +"
			text = text[0..-3]
		elsif (text.scan(/[\d,]+/).size == 2) && (text.scan(/[^\d^,^ ]/) == [] )
			text = text.scan(/[\d,]+/)[0]
		end
		text
	end

	def self.convert_to_integer(text)
		if text.gsub(",","").to_i.to_s == text.gsub(",","")
			text.gsub(",","").to_i
		else
			text
		end
	end

	def self.get_rows(table)
		trs = get_trs(table)
		rows = []
		trs.each do |tr|
			tds = get_tds(tr)
			tds = get_ths(tr) if tds.empty?
			row = tds.map do |td|
				if td.search("//span").empty?
					r = td.inner_html
				else
					r = td.search("//span").first.inner_html
					r = strip_span(r)
				end
				r = strip_a(r)
				r = strip_br(r)
				r = strip_nbsp(r)
				r = r.strip
				r = pick_element(r)
				r = convert_to_integer(r)
			end
			rows << row
		end
		rows
	end

	def self.get_tabs(tab_data)
		tab_data.search("//a").map{|a|a.inner_html}
	end

	def self.objectify_table_info(t)
		table = PCGS::Table.new(t[:coin_type], t[:tab_title], t[:coin_grade_type], t[:table])
		rows = PCGS.get_rows(t[:table]) rescue []
		table.add_rows(rows)
		table
	end
end
