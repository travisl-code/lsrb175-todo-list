require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  set :erb, :escape_html => true
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

  def sort_lists!(lists)
    # list_copy = lists.dup
    lists.sort_by! { |list| list_completed?(list) ? 1 : 0 }
  end

  def sort_todos(todos)
    todos.sort_by! { |todo| todo[:completed] ? 1: 0 }
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

# Input validation for retrieving a list
def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found"
  redirect '/lists'
end

# Render specific list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "List name updated successfully"
    redirect "/lists/#{@list_id}"
  end
end

# delete an existing list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at id

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax
    "/lists"
  else
    session[:success] = "List successfully deleted"
    redirect "/lists"
  end
end

# Get unique id for todo
def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

def select_todo(todos)
  todos.select { |todo| todo[:id] == @todo_id }.first
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params['todo'].strip
  @list = load_list(@list_id)
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: todo, completed: false }
    session[:success] = "Todo added"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  # original solution...
  # @todo_id = params[:todo_id].to_i
  # @list[:todos].delete_at(@todo_id)

  # new solution...
  @todo_id = params[:todo_id].to_i
  # to_delete = @list[:todos].select { |todo| todo[:id] == @todo_id }.first
  to_delete = select_todo(@list[:todos])
  @list[:todos].delete(to_delete)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax
    status 204 # OK, no content
  else
    session[:success] = "Todo successfully deleted"
    redirect "/lists/#{@list_id}"
  end
end

# Toggle a todo item complete/incomplete
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i
  to_toggle = select_todo(@list[:todos])

  toggle = params['completed'] == 'true'

  # original...
  # @list[:todos][@todo_id][:completed] = toggle 

  # new...
  to_toggle[:completed] = toggle
  session[:success] = "Todo status updated"
  redirect "/lists/#{@list_id}"
end

# Mark all todos done
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  
  session[:success] = "Todos completed"
  redirect "/lists/#{@list_id}"
end