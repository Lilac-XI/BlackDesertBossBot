require 'discordrb'
require 'date'
require 'time'
require 'csv'
require 'dotenv'

Dotenv.load

bot = Discordrb::Commands::CommandBot.new(
token: ENV["TOKEN"],
client_id: ENV["CLIENT_ID"],
prefix:'b ',
)

$boss_schedule = CSV.table("#{Dir.pwd}/schedules/boss_schedule.csv",headers: true,encoding: "UTF-8")
$time_schedule = CSV.table("#{Dir.pwd}/schedules/time_schedule.csv",headers: true,encoding: "UTF-8")
$timer_state = false
$loop_breaker = false
$check_schedule = [[90,660,960,1140,1380],[90,960,1140,1380],[90,660,960,1140],[90,660,960,1140,1350,1380]]
$adjust_state = true
#$voice_state = false

bot.command :next do |event|
	t = Time.now
	next_boss = next_boss_data(t.hour,t.min)
	message = "次のボスは#{next_boss[:time]}に#{next_boss[:name1]}"
	if next_boss[:name2] then
	 	message = message << " #{next_boss[:name2]}"
	end
	message = message << "です。"
	event.send_message(message)
 	
end

bot.command :set do |event,min,repeat|
	min ||= 15
	min = Integer(min)
	repeat ||= min
	$loop_breaker = false
	if $timer_state == false && min % 5 == 0
		event.send_message("まもなくタイマーが設定されます")
		$timer_state = true
		adjust
		event.send_message("タイマーがセットされました。ボス登場の#{min}分前に通知されます。")
		
		while $timer_state
			t = Time.now
			now = (t.hour * 60) + t.min
			x = schedule_selector
			$check_schedule[x].each do |i|
				if i - now <= min && i - now >= 0
					next_boss = next_boss_data(t.hour,t.min)
					event.send_message("#{next_boss[:time]}に#{next_boss[:name1]} #{next_boss[:name2]}が現れます！")
					$adjust_state = true
					sleep repeat * 60
				elsif i-now <= 60 && i - now > 30  && $adjust_state == true
					adjust
					$adjust_state = false
				end
			end
			sleep 299

			if $loop_breaker then
				$timer_state = false
				break
			end
		end
		event.send_message("タイマーは終了しました")
	elsif $timer_state == false
		event.send_message("設定値 #{min} タイマーは５で割り切れる数でセットしてください")
	else
		event.send_message("タイマーは既に設定されています")
	end
end

bot.command :off do |event|
	if $timer_state == true && $loop_breaker == false
		$loop_breaker = true
		next "しばらくするとタイマーがオフになります。"
	elsif $timer_state == true
		event.send_message("タイマーがオフになるまでしばらくお待ちください。")
	else
		event.send_message("タイマーはセットされていません")
	end
	
end



bot.command :today do |event|
	y = Date.today.wday
	today_schedule = $boss_schedule.select {|s| s[:wday] == y}
	message = "本日のボスのスケジュールは"
	today_schedule.each do |today|
		message = message + "\n"+"#{today[:time]} : #{today[:name1]} #{today[:name2]}"
	end
	message = message + "\nです。"
	event.send_message(message)
end


=begin
bot.command :join do |event|
	$voice_state = true
	channel = event.user.voice_channel
	if channel == nil
		event.send_message("ボイスチャンネルに接続できません。接続するには[b join]コマンドを入力するユーザーがボイスチャンネルに参加している必要があります。")
	else
		bot.voice_connect(channel)
		event.send_message("#{channel.name} に参加しました。")
	end
	
end

bot.command :kick do |event|
	if $voice_state then
		$voice_state = false
		bot.voice_destroy(event.server.id)
		next "Good Bye!"
	else
		event.send_message("Can not disconnect")
	end
	
end

bot.command :test do |event|
	if $voice_state then
		event.voice.play_file("#{Dir.pwd}/voice/次のボスは.wav")
	else
		event.send_message("TEST")
	end
	
end


					if $voice_state then
						event.voice.play_file("#{Dir.pwd}/voice/次のボスは.wav")
						event.voice.play_file("#{Dir.pwd}/voice/#{next_boss[:name1]}.wav")
						if next_boss[:name2] then
							event.voice.play_file("#{Dir.pwd}/voice/#{next_boss[:name2]}.wav")
						end
						event.voice.play_file("#{Dir.pwd}/voice/です.wav")
					end

=end

private
def next_boss_data(hour,min)
	min = one2two(min)
	y = Date.today.wday
	now = ("#{hour}#{min}").to_i
	time = $time_schedule.find{|row| row[:wday] == y && row[:preview_time] < now}
	next_time = time[:next_time]
	if next_time == "25:30" && now <= 130
		y = date_line(y)
	end
	next_boss = $boss_schedule.find{|row| row[:wday] == y && row[:time] == next_time}

	return next_boss
end

def one2two(min)
	min = "#{min}"
	if min.size == 1
		min = "0#{min}"
	end
	
	return min
end

def date_line(y)
	if y == 0
		y = 6
	else
		y = y - 1
	end

	return y
end

def schedule_selector
	y = Date.today.wday
	if y == 3
		x = 1
	elsif y == 6
		x = 2
	elsif y == 0
		x = 3
	else
		x = 0
	end

	return x
end

def adjust
	while $loop_breaker == false
		t = Time.now
		m = t.min
		if m % 5 == 0
			break
		end
		sleep 59
	end
end


bot.run