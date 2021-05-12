# Ensure that all extra applications that our app depends on are started.
# During testing we manually setup the individual parts instead.
Application.load(:bitpal)

for app <- Application.spec(:bitpal, :applications) do
  Application.ensure_all_started(app)
end

BitPal.Currencies.configure_money()

# For some reason logger doesn't take regular config settings when started this way...
Logger.configure(level: :warn)

ExUnit.start()
