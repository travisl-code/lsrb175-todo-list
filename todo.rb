require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret' # sets the session secret to string literal
end

before do
  session[:lists] ||= []
end

helpers do
  def list_completed?(list)
    !list[:todos].empty? && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    # list = session[:lists][list_id.to_i]
    "complete" if list_completed?(list)
  end

  def evaluate_todos_complete(list)
    num_total = list[:todos].size
    num_completed = list[:todos].select do |todo|
      todo[:completed]
    end.size
    
    "#{num_completed}/#{num_total}"
  end
end

get "/" do
  redirect '/lists'
end

# GET   /lists            --> view all lists
# GET   /lists/new        --> new list form
# POST  /lists            --> create new list
# GET   /lists/1          --> view a single list

# View all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Return an error message if name is invalid; nil if name valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "#List must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "#List must be unique."
  end
end

# Return error message if todo is invalid; nil if valid
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list been created.'
    redirect '/lists'
  end
end

# Render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  erb :edit_list, layout: :layout
end

# Update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  @id = params[:id].to_i
  @list = session[:lists][@id]
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "List name updated successfully"
    redirect "/lists/#{@id}"
  end
end

# delete an existing list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at id
  session[:success] = "List successfully deleted"
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params['todo'].strip
  @list = session[:lists][@list_id]
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = "Todo added"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(@todo_id)
  session[:success] = "Todo successfully deleted"
  redirect "/lists/#{@list_id}"
end

# Toggle a todo item complete/incomplete
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todo_id = params[:todo_id].to_i
  toggle = params['completed'] == 'true'

  @list[:todos][@todo_id][:completed] = toggle 
  session[:success] = "Todo status updated"
  redirect "/lists/#{@list_id}"
end

# Mark all todos done
post "/lists/:id/complete_all" do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  @list[:todos].each { |todo| todo[:completed] = true }
  
  session[:success] = "Todos completed"
  redirect "/lists/#{@id}"
end