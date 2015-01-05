controllers = angular.module 'hackboardControllers', []

# Login, Register Controller
controllers.controller 'UserCtrl', ['$scope', 'User', '$window', ($scope, User, $window)->
# 紀錄登入資訊的 Model
  $scope.loginInfo =
    email: "Alice@meigic.tw"
    password: "Alice0000"
    rememberMe: ""
    hasError: false
    hasWarning: false

  # 註冊資訊的Model
  $scope.registerInfo =
    email: ''
    nickname: ''
    password: ''
    password_confirmation: ''
    agree: false
    hasError: false
    hasWarning: false
    warning_message: ''
    nicknameDirty: false

  # 登入按鈕按下時要做的動作
  $scope.btnLogin = ()->
    # reset message
    $scope.loginInfo.hasError = false
    $scope.loginInfo.hasWarning = false

    User.login(
      $scope.loginInfo.email
      $scope.loginInfo.password
    )
    .success((data, status)->
      $window.location.href = '/boards'
      return
    )
    .error((data, status)->
      if data == "UMSE01" or data == "UMSE02"
        $scope.loginInfo.hasWarning = true
      else
        $scope.loginInfo.hasError = true
      return
    )
    return

  # 從登入轉到註冊卡片，並帶入資料
  $scope.btnRegister = ()->
    $scope.registerInfo.email = $scope.loginInfo.email
    resetAllError()
    switchCard $("#loginCard"), $("#signupCard")

  resetAllError = ()->
    $scope.loginInfo.hasError = $scope.loginInfo.hasWarning = $scope.registerInfo.hasError = $scope.registerInfo.hasWarning = false
    return

  resetSignUpAllError = ()->
    $scope.registerInfo.hasError = $scope.registerInfo.hasWarning = false
    $scope.registerInfo.warning_message = ''
    return

  cleanUpSignUpInformations = ()->
    $scope.registerInfo.email = $scope.registerInfo.nickname = $scope.registerInfo.password = $scope.registerInfo.password_confirmation = ''
    $scope.registerInfo.agree = false
    return

  #按下註冊鈕
  $scope.btnSignUp = ()->
    #Reset
    $scope.registerInfo.hasError = false
    $scope.registerInfo.hasWarning = false
    $scope.registerInfo.warning_message = ''

    #Check shortname is match pattern
    if $scope.signUpForm.nickName.$error.required or $scope.signUpForm.nickName.$error.pattern
      $scope.registerInfo.hasWarning = true
      $scope.registerInfo.warning_message = 'Your short name dose not match the pattern. '
      return
    #Check password and passwordConfirmation at least 8 character
    if $scope.signUpForm.password.$error.minlength or $scope.signUpForm.password_confirmation.$error.minlength
      $scope.registerInfo.hasWarning = true
      $scope.registerInfo.warning_message = 'Your password needs at least 8 characters.'
      return
    #Check password and passwordConfirmation match pattern
    if $scope.signUpForm.password.$error.pattern or $scope.signUpForm.password_confirmation.$error.pattern
      $scope.registerInfo.hasWarning = true
      $scope.registerInfo.warning_message = 'Your password does not match the pattern.'
      return
    #Check password and passwordConfirmation are same...
    if $scope.registerInfo.password != $scope.registerInfo.password_confirmation
      $scope.registerInfo.hasWarning = true
      $scope.registerInfo.warning_message = 'Passwords are not the same.'
      return
    #Check agree checkbox is checked
    if $scope.registerInfo.agree == false
      $scope.registerInfo.hasWarning = true
      $scope.registerInfo.warning_message = 'You need to agree Term of Service.'
      return

    #Sign up...
    User.signUp(
      $scope.registerInfo.email,
      $scope.registerInfo.nickname,
      $scope.registerInfo.password,
      $scope.registerInfo.password_confirmation
    )
    .success((data, status)->
      $scope.loginInfo.email = $scope.registerInfo.email
      $scope.loginInfo.password = ''
      #clean up ...
      cleanUpSignUpInformations()
      resetSignUpAllError()
      #Flip to login scene
      switchCard $('#signupCard'), $('#loginCard')
    )
    .error((data, status)->
      if data == "UMSE03"
        $scope.registerInfo.hasWarning = true
        $scope.registerInfo.warning_message = 'Account already exist.'
        return
      else if data == "UMSE04"
        $scope.registerInfo.hasWarning = true
        $scope.registerInfo.warning_message = 'Passwords dose not the same.'
        return
      else
        $scope.registerInfo.hasError = true
    )
    return

  #Change shortname when email been done (Cannot change when type in email account)
  $scope.putToNickname = ()->
    if !$scope.signUpForm.signUpEmail.$error.pattern
      $scope.registerInfo.nickname = $scope.registerInfo.email.split("@")[0]
    return

  return
]

# Boards Page
controllers.controller 'BoardsCtrl', ['$scope', 'User', 'Board', '$window', ($scope, User, Board, $window, timeAgo)->
  $scope.boards = {
    pin: [],
    other: []
  }

  # async load boards data
  Board.boards().success((data, status)->
    $scope.boards = data
  )

  # sortable setting
  $scope.pinBoardSortOptions = {
    containment: '#pinned-boards',
    additionalPlaceholderClass: 'ui column',
    accept: (sourceItemHandleScope, destSortableScope)->
      sourceItemHandleScope.itemScope.sortableScope.$id == destSortableScope.$id
  }

  $scope.otherBoardSortOptions = {
    containment: '#other-boards',
    additionalPlaceholderClass: 'ui column',
    accept: (sourceItemHandleScope, destSortableScope)->
      sourceItemHandleScope.itemScope.sortableScope.$id == destSortableScope.$id
  }

  # processing pin and unpin

  $scope.pin = (id)->
    angular.forEach $scope.boards.other, (value, key)->
      if value.id == id
        $scope.boards.pin.push $scope.boards.other[key]
        $scope.boards.other.splice key, 1
        Board.pin(id)
    return

  $scope.unpin = (id)->
    angular.forEach $scope.boards.pin, (value, key)->
      if value.id == id
        $scope.boards.other.push $scope.boards.pin[key]
        $scope.boards.pin.splice key, 1
        Board.unpin(id)
    return

  # new board
  $scope.newBoard = ()->
    Board.create().success((data, status)->
#      $scope.boards.other.push data.board
      $window.location.href = '/board/' + data.board.id
    )
    return

  # click card to board
  $scope.toBoard = (id)->
    $window.location.href = '/board/' + id
]

# board Page
controllers.controller 'BoardCtrl', ['$scope', '$window', 'Board' , '$http', ($scope, $window, Board , $http)->
  board_id = parseInt($window.location.pathname.split('/')[2])
  $scope.board = [
    flows: []
  ]
  # flow sortable setting
  $scope.flowSortOptions = {
    containment: '#board-content',
    additionalPlaceholderClass: 'ui grid ui-board-content',
    accept: (sourceItemHandleScope, destSortableScope)->
      sourceItemHandleScope.itemScope.sortableScope.$id == destSortableScope.$id
  }

  $scope.taskSortOptions = {
#    containment: '#board-content',
#    additionalPlaceholderClass: 'ui grid ui-board-content',
#    accept: (sourceItemHandleScope, destSortableScope)->
#      sourceItemHandleScope.itemScope.sortableScope.$id == destSortableScope.$id
  }

  Board.board(board_id).success((data, status)->
    $scope.board = data

    Board.flows($scope.board.id).success((data , status)->
      $scope.board.flows = data
      console.log $scope.board
    )

  ).error((data, status)->
    $window.location.href = "/boards"
  )

  $scope.taskClick = (id)->

    $http.get('/api/task/' + id).success((data, status)->

      $scope.taskData = data

      $('.ui.modal').modal({
        transition: 'slide down',
        duration: '100ms'
      }).modal('show')

    )
    return

  $scope.removeBoardMember = (id)->
    angular.forEach($scope.board.users , (value,key)->
      if value.id == id
        $scope.board.users.splice key,1
    )
    return

  $scope.newFlow = ()->
    $http.post('/api/boards/' + $scope.board.id + '/flows/add').success((data,status)->
      $scope.board.flows.push data
    )
    return

  $scope.newTask = (id)->
    $http.post('/api/boards/' + $scope.board.id + '/flows/' + id + '/task/add').success(
      (data,status)->
        angular.forEach($scope.board.flows , (flow , key)->
          angular.forEach(flow.flows , (subFlow , key2)->
            if subFlow.id == id
              subFlow.tasks.push data
          )
          if flow.id == id
            flow.tasks.push data
        )
    )
    return

]