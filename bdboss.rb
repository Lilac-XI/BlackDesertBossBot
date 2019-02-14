require 'discordrb'
require 'date'
require 'time'
require 'csv'
require 'dotenv'

Dotenv.load

bot = Discordrb::Commands::CommandBot.new(
token: ENV["TOKEN"],
client_id: ENV["CLIENT_ID"],
prefix:'bb ',
)

$boss_schedule = CSV.table("#{Dir.pwd}/schedules/boss_schedule.csv",headers: true)
$time_schedule = CSV.table("#{Dir.pwd}/schedules/time_schedule.csv",headers: true)
$voice_state = false
$timer_state = false
$loop_breaker = false

bot.command :next do |event|
	t = Time.now
	next_boss = next_boss_data(t.hour,t.min)
	if next_boss[:name1] == nil
		event.send_message("Nil")
	else
		event.send_message("次のボスは#{next_boss[:time]}に#{next_boss[:name1]} #{next_boss[:name2]}です")
	end
 	
end

bot.command :join do |event|
	$voice_state = true
	channel = event.user.voice_channel
	bot.voice_connect(channel)
	next "Connected to voice channel: #{channel.name}"
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

bot.command :set do |event,min|
	min = Integer(min)
	$loop_breaker = false
	event.send_message("まもなくタイマーが設定されます")
	if ($timer_state == false && min % 5 == 0) then
		$timer_state = true
		while $timer_state
			t = Time.now
			m = t.min
			if m % 5 == 0
				break
			end
			sleep 60
		end
		event.send_message("タイマーがセットされました。ボス登場の#{min}分前に通知されます。")
		boss_schedule = [90,660,960,1140,1380]
		while $timer_state
			if $loop_breaker then
				$timer_state = false
				break
			end
			t = Time.now
			now = (t.hour * 60) + t.min
			boss_schedule.each do |i|
				if i - now <= min
					next_boss = next_boss_data(t.hour,t.min)
					event.send_message("#{next_boss[:time]}に#{next_boss[:name1]} #{next_boss[:name2]}が現れます！")
					if $voice_state then
						event.voice.play_file("#{Dir.pwd}/voice/次のボスは.wav")
						event.voice.play_file("#{Dir.pwd}/voice/#{next_boss[:name1]}.wav")
						if next_boss[:name2] then
							event.voice.play_file("#{Dir.pwd}/voice/#{next_boss[:name2]}.wav")
						end
						event.voice.play_file("#{Dir.pwd}/voice/です.wav")
					end
					sleep min * 60
				end
			end
			sleep 299
		end
		event.send_message("タイマーは終了しました")
	elsif $timer_state == false
		event.send_message("設定値 #{} タイマーは５で割り切れる数でセットしてください")
	else
		event.send_message("タイマーは既に設定されています")
	end
end

bot.command :off do |event|
	if $timer_state == true && $loop_breaker == false
		$loop_breaker = true
		next "しばらくするとタイマーがオフになります。"
	elsif $timer_state == true
		event.send_message("タイマがオフになるまでしばらくおl待ちください。")
	else
		event.send_message("タイマーはセットされていません")
	end
	
end

def next_boss_data(hour,min)
	y = Date.today.wday
	now = Integer("#{hour}#{min}")
	time = $time_schedule.find{|row| row[:wday] == y && row[:preview_time] < now}
	next_time = time[:next_time]
	if next_time == "01:30"
		if y == 6
			y = 0
		else
			y = y + 1
		end
	end
	next_boss = $boss_schedule.find{|row| row[:wday] == y && row[:time] == next_time}
	return next_boss
end
bot.run